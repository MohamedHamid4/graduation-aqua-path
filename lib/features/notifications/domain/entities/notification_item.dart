import 'package:equatable/equatable.dart';

/// A single push notification actually received by this device, persisted
/// so the resident's notifications screen can show real history instead of
/// an ephemeral OS banner that vanishes the moment it's dismissed.
///
/// Stored at `user_notifications/{uid}/items/{id}`, where `id` is the FCM
/// `messageId` — using it as the document id makes writing on receipt
/// naturally idempotent (a redelivered message overwrites the same doc
/// instead of duplicating it).
class NotificationItem extends Equatable {
  final String id;
  final String title;
  final String body;
  final String type; // 'delivery_confirmed' | 'org_broadcast' | 'unknown'
  final String? areaName;
  final bool read;
  final DateTime receivedAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.areaName,
    this.read = false,
    required this.receivedAt,
  });

  factory NotificationItem.fromMap(String id, Map<String, dynamic> data) {
    final receivedAt = data['receivedAt'];
    return NotificationItem(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'unknown',
      areaName: data['areaName'] as String?,
      read: data['read'] as bool? ?? false,
      // receivedAt is written with FieldValue.serverTimestamp(); a doc
      // read from local cache before the server round-trip completes can
      // briefly report it as null — falling back to "now" for that one
      // frame is preferable to crashing or sorting the item to the epoch.
      receivedAt: receivedAt is DateTime
          ? receivedAt
          : (receivedAt?.toDate() as DateTime?) ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, title, body, type, areaName, read, receivedAt];
}
