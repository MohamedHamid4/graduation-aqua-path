import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_colors.dart';
import 'core/errors/global_exception_handler.dart';
import 'core/logging/app_logger.dart';
import 'core/network/connectivity_service.dart';
import 'core/offline/offline_write_queue_service.dart';
import 'firebase_options.dart';
import 'injection.dart';
import 'shared/providers/notification_prefs_provider.dart';
import 'shared/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Environment configuration ──────────────────────────────────────
  AppConfig.init();
  AppLogger.info('Starting AquaPath — ${AppConfig.instance}', tag: 'Main');

  // ── 2. Install global synchronous + platform error handlers ───────────
  GlobalExceptionHandler.install();
  ErrorWidget.builder = GlobalExceptionHandler.errorWidgetBuilder;

  // ── 3. Zone guard — catches all unhandled async errors ────────────────
  await runZonedGuarded<Future<void>>(
    () async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Wire Flutter and platform errors to Crashlytics in production.
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      AppLogger.info('Firebase initialised', tag: 'Main');

      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      await Hive.initFlutter();
      await Hive.openBox<String>('truckCache');
      await Hive.openBox<String>('settings');
      await Hive.openBox<dynamic>('householdData');
      await Hive.openBox<String>('offlineQueue');
      AppLogger.info('Hive boxes opened', tag: 'Main');

      await configureDependencies();
      AppLogger.info('DI container ready', tag: 'Main');

      await getIt<PushNotificationService>().initialize();

      // Flush anything queued from a previous offline session, then keep
      // flushing every time connectivity comes back — this is the only
      // place the app needs to know about the offline queue at all;
      // every repository that uses it just enqueues and moves on.
      unawaited(getIt<OfflineWriteQueueService>().flush());
      getIt<ConnectivityService>().onConnectivityChanged.listen((isOnline) {
        if (isOnline) {
          unawaited(getIt<OfflineWriteQueueService>().flush());
        }
      });

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.bgPrimary,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      final container = ProviderContainer();
      await container
          .read(notificationPrefsProvider.notifier)
          .loadFromStorage();

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const AquaPathApp(),
        ),
      );

      AppLogger.info('AquaPath launched successfully', tag: 'Main');
    },
    (Object error, StackTrace stack) {
      AppLogger.fatal(
        'Uncaught zone error in main',
        tag: 'Zone',
        error: error,
        stackTrace: stack,
      );
    },
  );
}
