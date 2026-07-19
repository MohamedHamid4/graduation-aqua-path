import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/logging/app_logger.dart';
import '../../core/security/secure_storage_service.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/notifications/data/datasources/notification_history_firebase_source.dart';
import '../../features/notifications/domain/repositories/notification_history_repository.dart';
import '../../firebase_options.dart';

/// Background FCM handler — must be a top-level function. Runs in its own
/// isolate (spawned by the OS, not by `main()`), so the app's GetIt/
/// Riverpod containers from the main isolate simply don't exist here —
/// Firebase has to be initialized independently, and Firestore is used
/// directly rather than through the DI-injected repository the rest of
/// this file uses.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.info(
    'Background FCM received: ${message.messageId}',
    tag: 'FCM',
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FirebaseAuth persists its session to disk, so the signed-in user is
  // already available here even though this isolate never ran the app's
  // normal sign-in flow.
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final messageId = message.messageId;
  if (uid == null || messageId == null) return;

  try {
    await NotificationHistoryFirebaseSource(FirebaseFirestore.instance)
        .recordReceived(
      uid: uid,
      messageId: messageId,
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      type: message.data['type'] as String? ?? 'unknown',
      areaName: message.data['areaName'] as String?,
    );
  } catch (e, st) {
    AppLogger.error(
      'Failed to persist background notification',
      tag: 'FCM',
      error: e,
      stackTrace: st,
    );
  }
}

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SecureStorageService _storage;
  final NotificationHistoryRepository _notificationHistory;
  final AuthRepository _authRepository;

  PushNotificationService(
    this._storage,
    this._notificationHistory,
    this._authRepository,
  );

  Future<void> initialize() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      AppLogger.info(
        'FCM permission: ${settings.authorizationStatus.name}',
        tag: 'FCM',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.warning('FCM permission denied by user', tag: 'FCM');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        AppLogger.info('FCM token obtained', tag: 'FCM');
        await _storage.saveFcmToken(token);
      }

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);
    } on Exception catch (e, st) {
      AppLogger.error(
        'FCM initialization failed',
        tag: 'FCM',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    AppLogger.info(
      'Foreground FCM: ${message.notification?.title}',
      tag: 'FCM',
    );

    final uid = _authRepository.currentUser?.uid;
    final messageId = message.messageId;
    if (uid == null || messageId == null) return;

    unawaited(
      _notificationHistory
          .recordReceived(
            uid: uid,
            messageId: messageId,
            title: message.notification?.title ?? '',
            body: message.notification?.body ?? '',
            type: message.data['type'] as String? ?? 'unknown',
            areaName: message.data['areaName'] as String?,
          )
          .then((result) => result.fold(
                (failure) => AppLogger.warning(
                  'Failed to persist notification: ${failure.message}',
                  tag: 'FCM',
                ),
                (_) {},
              )),
    );
  }

  void _onNotificationTap(RemoteMessage message) {
    AppLogger.info(
      'User tapped notification: ${message.messageId}',
      tag: 'FCM',
    );

    final uid = _authRepository.currentUser?.uid;
    final messageId = message.messageId;
    if (uid == null || messageId == null) return;

    // The tapped notification was already persisted by whichever handler
    // received it first (foreground onMessage, or the background isolate
    // handler above) — opening it just marks that existing record read.
    unawaited(_notificationHistory.markRead(uid: uid, itemId: messageId));
  }

  /// FCM topic names must match `[a-zA-Z0-9-_.~%]+` — Arabic area names
  /// (the overwhelming majority of AquaPath's actual area names) contain
  /// characters outside that set, so a naive `area_$areaName` topic
  /// would be silently rejected or never matched. This hex-encodes each
  /// UTF-16 code unit into a deterministic, always-valid topic suffix.
  /// The Cloud Function that publishes delivery notifications
  /// (`functions/src/index.ts`, `sanitizeTopic`) uses the identical
  /// encoding — the two must never diverge, or notifications silently
  /// stop matching subscriptions.
  static String topicSuffixFor(String areaName) {
    final normalized = areaName.trim();
    return normalized.codeUnits
        .map((c) => c.toRadixString(16).padLeft(4, '0'))
        .join();
  }

  Future<void> subscribeToArea(String areaName) async {
    final topic = 'area_${topicSuffixFor(areaName)}';
    await _messaging.subscribeToTopic(topic);
    AppLogger.info('Subscribed to FCM topic: $topic', tag: 'FCM');
  }

  Future<void> unsubscribeFromArea(String areaName) async {
    final topic = 'area_${topicSuffixFor(areaName)}';
    await _messaging.unsubscribeFromTopic(topic);
    AppLogger.info('Unsubscribed from FCM topic: $topic', tag: 'FCM');
  }
}
