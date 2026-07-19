import 'package:equatable/equatable.dart';

/// An organization-authored notification, stored at
/// `notifications/{id}` and fanned out to residents via FCM by the
/// `onNotificationCreated` Cloud Function (see `functions/src/index.ts`)
/// — the Firestore document is both the durable "sent history" record
/// and the trigger payload for the actual push.
class OrgNotification extends Equatable {
  final String id;
  final String title;
  final String body;

  /// Null/empty means broadcast to every registered area.
  final String? areaName;
  final DateTime createdAt;

  const OrgNotification({
    required this.id,
    required this.title,
    required this.body,
    this.areaName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        if (areaName != null && areaName!.isNotEmpty) 'areaName': areaName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OrgNotification.fromMap(String id, Map<String, dynamic> data) {
    return OrgNotification(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      areaName: data['areaName'] as String?,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, title, body, areaName, createdAt];
}
