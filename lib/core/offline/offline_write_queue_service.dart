import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import '../errors/failure_mapper.dart';
import '../errors/failures.dart';
import '../logging/app_logger.dart';

/// A single pending write, queued while offline and replayed once
/// connectivity returns.
///
/// Deliberately scoped to **doc-keyed `set(..., merge: true)` writes
/// only** — the one Firestore write shape that's genuinely safe to queue
/// blindly and replay later without first reading current server state.
/// This is why the offline queue is wired into household registration
/// and driver-profile registration (both `set(uid, ..., merge: true)`
/// against a doc whose ID is already known client-side) but deliberately
/// **not** into parking-spot stop registration — that operation reads
/// the nearest existing spot first to decide whether to increment it or
/// create a new one, and blindly replaying a stale "increment" decision
/// after being offline for a while risks either double-counting a stop
/// or creating a duplicate cluster. A read-then-write operation needs a
/// proper conflict-aware sync strategy, not this queue; see the P1
/// tracking note in the review report for that follow-up.
class QueuedWrite {
  final String id;
  final String collection;
  final String docId;
  final Map<String, dynamic> data;
  final DateTime queuedAt;

  const QueuedWrite({
    required this.id,
    required this.collection,
    required this.docId,
    required this.data,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'collection': collection,
        'docId': docId,
        'data': data,
        'queuedAt': queuedAt.toIso8601String(),
      };

  factory QueuedWrite.fromJson(Map<String, dynamic> json) => QueuedWrite(
        id: json['id'] as String,
        collection: json['collection'] as String,
        docId: json['docId'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
        queuedAt: DateTime.parse(json['queuedAt'] as String),
      );
}

/// Persists [QueuedWrite]s to a Hive box so they survive an app restart
/// while offline, and replays them against Firestore once connectivity
/// is restored (see `main.dart`, which calls [flush] on every
/// `ConnectivityService.onConnectivityChanged` transition to `true`, and
/// once at startup in case writes were queued during a previous session
/// that never came back online before the app was closed).
class OfflineWriteQueueService {
  final Box<String> _box;
  final FirebaseFirestore _firestore;

  static const _queueKey = 'pending_writes';

  OfflineWriteQueueService(this._box, this._firestore);

  Future<void> enqueue({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final pending = _readAll();
    pending.add(QueuedWrite(
      id: '${DateTime.now().microsecondsSinceEpoch}_$docId',
      collection: collection,
      docId: docId,
      data: data,
      queuedAt: DateTime.now(),
    ));
    await _writeAll(pending);
    AppLogger.info(
      'Queued offline write: $collection/$docId (${pending.length} pending)',
      tag: 'OfflineQueue',
    );
  }

  List<QueuedWrite> _readAll() {
    final raw = _box.get(_queueKey);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => QueuedWrite.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Corrupt offline queue, dropping it',
          tag: 'OfflineQueue', error: e);
      return [];
    }
  }

  Future<void> _writeAll(List<QueuedWrite> writes) async {
    await _box.put(
        _queueKey, jsonEncode(writes.map((w) => w.toJson()).toList()));
  }

  int get pendingCount => _readAll().length;

  bool get hasPending => pendingCount > 0;

  /// Replays every queued write in the order it was queued. A write that
  /// fails (still offline, or a genuine server rejection) stays in the
  /// queue and stops the flush — later writes for the same document
  /// shouldn't jump ahead of an earlier one that hasn't landed yet.
  Future<void> flush() async {
    final pending = _readAll();
    if (pending.isEmpty) return;

    AppLogger.info('Flushing ${pending.length} queued offline write(s)',
        tag: 'OfflineQueue');

    final remaining = <QueuedWrite>[];
    var stopped = false;

    for (final write in pending) {
      if (stopped) {
        remaining.add(write);
        continue;
      }
      try {
        await _firestore
            .collection(write.collection)
            .doc(write.docId)
            .set(write.data, SetOptions(merge: true));
        AppLogger.info(
          'Flushed queued write: ${write.collection}/${write.docId}',
          tag: 'OfflineQueue',
        );
      } catch (e, st) {
        final failure = FailureMapper.map(e, st, tag: 'OfflineQueue');
        if (failure is NetworkFailure) {
          // Genuinely still unreachable — keep it queued and stop so
          // later writes don't jump ahead of one that hasn't landed yet.
          remaining.add(write);
          stopped = true;
        } else {
          // A real rejection (permission-denied, invalid data, etc.) will
          // never succeed no matter how many times it's replayed —
          // silently keeping it queued forever means the user's change is
          // lost with zero visibility. Log it loudly (reaches Crashlytics
          // in release) so it's actually diagnosable, and drop it rather
          // than block every future flush behind a write that can never
          // land.
          AppLogger.error(
            'Dropping permanently-failing queued write: '
            '${write.collection}/${write.docId} — ${failure.message}',
            tag: 'OfflineQueue',
            error: e,
            stackTrace: st,
          );
        }
      }
    }

    await _writeAll(remaining);
  }
}
