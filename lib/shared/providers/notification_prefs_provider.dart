import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../core/security/secure_storage_service.dart';
import '../services/push_notification_service.dart';

/// Selectable geofence radii (metres) shown in the settings radius picker.
const List<int> kNotificationRadiusOptions = [250, 500, 1000, 2000];

class NotificationPrefs {
  const NotificationPrefs({
    this.enabled = true,
    this.radiusMeters = 500,
  });

  final bool enabled;
  final int radiusMeters;

  NotificationPrefs copyWith({bool? enabled, int? radiusMeters}) {
    return NotificationPrefs(
      enabled: enabled ?? this.enabled,
      radiusMeters: radiusMeters ?? this.radiusMeters,
    );
  }
}

class NotificationPrefsNotifier extends Notifier<NotificationPrefs> {
  @override
  NotificationPrefs build() => const NotificationPrefs();

  SecureStorageService get _storage => GetIt.I<SecureStorageService>();

  /// Reads persisted values — call once at app start (see main.dart).
  Future<void> loadFromStorage() async {
    final enabled = await _storage.notificationsEnabled;
    final radius = await _storage.notificationRadiusMeters;
    state = NotificationPrefs(enabled: enabled, radiusMeters: radius);
  }

  Future<void> setEnabled({required bool value}) async {
    state = state.copyWith(enabled: value);
    await _storage.setNotificationsEnabled(value: value);

    final area = await _storage.savedArea;
    if (area == null || area.isEmpty) return;

    final push = GetIt.I<PushNotificationService>();
    if (value) {
      await push.subscribeToArea(area);
    } else {
      await push.unsubscribeFromArea(area);
    }
  }

  Future<void> setRadiusMeters(int meters) async {
    state = state.copyWith(radiusMeters: meters);
    await _storage.setNotificationRadiusMeters(meters);
  }
}

final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
  NotificationPrefsNotifier.new,
);
