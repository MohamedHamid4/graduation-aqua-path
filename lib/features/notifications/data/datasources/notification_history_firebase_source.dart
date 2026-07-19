import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/notification_item.dart';

class NotificationHistoryFirebaseSource {
  final FirebaseFirestore _firestore;

  NotificationHistoryFirebaseSource(this._firestore);

  CollectionReference _itemsRef(String uid) => _firestore
      .collection('user_notifications')
      .doc(uid)
      .collection('items');

  Stream<List<NotificationItem>> watchNotifications(String uid) {
    return _itemsRef(uid)
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => NotificationItem.fromMap(
                    d.id,
                    d.data() as Map<String, dynamic>,
                  ))
              .toList(),
        );
  }

  /// Doc id = the FCM messageId, so a redelivered/duplicate-processed
  /// message overwrites the same record instead of creating a second one.
  Future<void> recordReceived({
    required String uid,
    required String messageId,
    required String title,
    required String body,
    required String type,
    String? areaName,
  }) {
    return _itemsRef(uid).doc(messageId).set({
      'title': title,
      'body': body,
      'type': type,
      if (areaName != null) 'areaName': areaName,
      'read': false,
      'receivedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markRead(String uid, String itemId) {
    return _itemsRef(uid).doc(itemId).set(
      {'read': true},
      SetOptions(merge: true),
    );
  }

  Future<void> markAllRead(String uid) async {
    final unread = await _itemsRef(uid).where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
