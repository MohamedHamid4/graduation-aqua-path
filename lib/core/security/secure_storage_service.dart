import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';

abstract final class StorageKeys {
  static const fcmToken = 'fcm_token';
  static const householdId = 'household_id';
  static const onboardingComplete = 'onboarding_complete';
  static const registrationComplete = 'registration_complete';
  static const selectedArea = 'selected_area';
  static const notificationsEnabled = 'notifications_enabled';
  static const notificationRadiusMeters = 'notification_radius_meters';
  static const deliveryRemindersEnabled = 'delivery_reminders_enabled';

  /// Persists the account-type chosen on the sign-up screen ('driver' or
  /// 'resident') the instant it's picked — read by the router's redirect
  /// logic right after Firebase Auth confirms sign-up, since Firestore has
  /// no driver/household profile yet to distinguish the two at that
  /// moment. See app_router.dart's redirect callback.
  static const pendingAccountRole = 'pending_account_role';
}

class SecureStorageService {
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const _storage = FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e, st) {
      AppLogger.error(
        'SecureStorage write failed for key=$key',
        tag: 'SecureStorage',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e, st) {
      AppLogger.error(
        'SecureStorage read failed for key=$key',
        tag: 'SecureStorage',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      AppLogger.warning(
        'SecureStorage delete failed for key=$key',
        tag: 'SecureStorage',
      );
    }
  }

  Future<void> writeBool(String key, {required bool value}) async {
    await write(key, value.toString());
  }

  Future<bool> readBool(String key, {bool defaultValue = false}) async {
    final raw = await read(key);
    if (raw == null) return defaultValue;
    return raw == 'true';
  }

  Future<bool> get isOnboardingComplete =>
      readBool(StorageKeys.onboardingComplete);

  Future<void> setOnboardingComplete() =>
      writeBool(StorageKeys.onboardingComplete, value: true);

  Future<bool> get isRegistrationComplete =>
      readBool(StorageKeys.registrationComplete);

  Future<void> setRegistrationComplete({required String householdId}) async {
    await writeBool(StorageKeys.registrationComplete, value: true);
    await write(StorageKeys.householdId, householdId);
  }

  Future<String?> get savedArea => read(StorageKeys.selectedArea);

  Future<void> setPendingAccountRole(String role) =>
      write(StorageKeys.pendingAccountRole, role);

  Future<String?> get pendingAccountRole =>
      read(StorageKeys.pendingAccountRole);

  Future<void> clearPendingAccountRole() =>
      delete(StorageKeys.pendingAccountRole);

  Future<void> saveArea(String area) => write(StorageKeys.selectedArea, area);

  Future<bool> get notificationsEnabled =>
      readBool(StorageKeys.notificationsEnabled, defaultValue: true);

  Future<void> setNotificationsEnabled({required bool value}) =>
      writeBool(StorageKeys.notificationsEnabled, value: value);

  Future<int> get notificationRadiusMeters async {
    final raw = await read(StorageKeys.notificationRadiusMeters);
    return int.tryParse(raw ?? '') ?? 500;
  }

  Future<void> setNotificationRadiusMeters(int meters) =>
      write(StorageKeys.notificationRadiusMeters, meters.toString());

  Future<bool> get deliveryRemindersEnabled =>
      readBool(StorageKeys.deliveryRemindersEnabled);

  Future<void> setDeliveryRemindersEnabled({required bool value}) =>
      writeBool(StorageKeys.deliveryRemindersEnabled, value: value);

  Future<void> saveFcmToken(String token) => write(StorageKeys.fcmToken, token);

  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      AppLogger.info('SecureStorage cleared', tag: 'SecureStorage');
    } catch (e) {
      AppLogger.warning('SecureStorage clearAll failed', tag: 'SecureStorage');
    }
  }
}
