import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/logging/app_logger.dart';
import '../../core/security/secure_storage_service.dart';

/// Background FCM handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.info(
    'Background FCM received: ${message.messageId}',
    tag: 'FCM',
  );
}

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SecureStorageService _storage;

  PushNotificationService(this._storage);

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
  }

  void _onNotificationTap(RemoteMessage message) {
    AppLogger.info(
      'User tapped notification: ${message.messageId}',
      tag: 'FCM',
    );
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
