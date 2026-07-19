import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/notification_item.dart';

/// Contract for the resident's own received-notification history —
/// distinct from `notifications/{id}`, which is the organization's
/// broadcast *send* log (see OrganizationRepository / NotificationCenter).
/// This repository is what actually backs what a resident sees on their
/// own device.
abstract class NotificationHistoryRepository {
  /// Live stream of everything received by this user, newest first.
  Stream<Either<Failure, List<NotificationItem>>> watchNotifications(
    String uid,
  );

  /// Persists a just-received push. Called from the FCM foreground/
  /// background handlers, never from the UI.
  Future<Either<Failure, Unit>> recordReceived({
    required String uid,
    required String messageId,
    required String title,
    required String body,
    required String type,
    String? areaName,
  });

  Future<Either<Failure, Unit>> markRead({
    required String uid,
    required String itemId,
  });

  Future<Either<Failure, Unit>> markAllRead(String uid);
}
