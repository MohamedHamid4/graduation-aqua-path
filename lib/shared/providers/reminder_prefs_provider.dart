import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../core/security/secure_storage_service.dart';

/// Whether the resident wants a reminder before each scheduled delivery.
///
/// This only persists the on/off preference (mirrors
/// [NotificationPrefsNotifier]'s pattern in notification_prefs_provider.dart)
/// — there is currently no scheduling pipeline that actually fires a
/// reminder ahead of a [DriverRoute]'s `scheduledTime` (that would need a
/// local-notification scheduler wired to upcomingAreaRoutesProvider, which
/// doesn't exist yet). Toggling this no longer silently resets on every
/// app restart, but turning it on does not yet cause a reminder to fire;
/// that's a separate follow-up.
class DeliveryReminderNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  SecureStorageService get _storage => GetIt.I<SecureStorageService>();

  /// Reads the persisted value — call once at app start (see main.dart).
  Future<void> loadFromStorage() async {
    state = await _storage.deliveryRemindersEnabled;
  }

  Future<void> setEnabled({required bool value}) async {
    state = value;
    await _storage.setDeliveryRemindersEnabled(value: value);
  }
}

final deliveryReminderProvider =
    NotifierProvider<DeliveryReminderNotifier, bool>(
  DeliveryReminderNotifier.new,
);
