import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../logging/app_logger.dart';

abstract final class GlobalExceptionHandler {
  static void install() {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.silent) return;

      AppLogger.error(
        'Flutter framework error — ${details.exceptionAsString()}',
        tag: 'FlutterError',
        error: details.exception,
        stackTrace: details.stack,
      );

      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      AppLogger.fatal(
        'PlatformDispatcher uncaught error',
        tag: 'PlatformDispatcher',
        error: error,
        stackTrace: stack,
      );
      return true;
    };
  }

  static Future<void> run(Future<void> Function() body) async {
    await runZonedGuarded<Future<void>>(
      body,
      (Object error, StackTrace stack) {
        AppLogger.fatal(
          'Uncaught zone error',
          tag: 'Zone',
          error: error,
          stackTrace: stack,
        );
      },
    );
  }

  static Widget errorWidgetBuilder(FlutterErrorDetails details) {
    if (kDebugMode) return ErrorWidget(details.exception);

    return const Material(
      color: AppColors.bgPrimary,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 56,
              ),
              SizedBox(height: 20),
              Text(
                'حدث خطأ غير متوقع',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'يرجى إغلاق التطبيق وإعادة فتحه',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
