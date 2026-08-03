import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notification_history_repository.dart';
import '../datasources/notification_history_firebase_source.dart';

const _tag = 'NotificationHistory';

class NotificationHistoryRepositoryImpl
    implements NotificationHistoryRepository {
  final NotificationHistoryFirebaseSource _source;

  NotificationHistoryRepositoryImpl(this._source);

  @override
  Stream<Either<Failure, List<NotificationItem>>> watchNotifications(
    String uid,
  ) =>
      FailureMapper.mapStream(
        () => _source.watchNotifications(uid),
        (items) => items,
        tag: _tag,
      );

  @override
  Future<Either<Failure, Unit>> recordReceived({
    required String uid,
    required String messageId,
    required String title,
    required String body,
    required String type,
    String? areaName,
  }) async {
    try {
      await _source.recordReceived(
        uid: uid,
        messageId: messageId,
        title: title,
        body: body,
        type: type,
        areaName: areaName,
      );
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, Unit>> markRead({
    required String uid,
    required String itemId,
  }) async {
    try {
      await _source.markRead(uid, itemId);
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, Unit>> markAllRead(String uid) async {
    try {
      await _source.markAllRead(uid);
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }
}
