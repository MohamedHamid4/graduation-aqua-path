import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

abstract final class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 100,
      colors: kDebugMode,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: kDebugMode ? ConsoleOutput() : _ReleaseOutput(),
    level: kDebugMode ? Level.trace : Level.warning,
  );

  static void trace(String message, {String? tag}) =>
      _logger.t(_tag(message, tag));

  static void debug(String message, {String? tag}) =>
      _logger.d(_tag(message, tag));

  static void info(String message, {String? tag}) =>
      _logger.i(_tag(message, tag));

  static void warning(String message, {String? tag, Object? error}) =>
      _logger.w(_tag(message, tag), error: error);

  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _logger.e(_tag(message, tag), error: error, stackTrace: stackTrace);

  static void fatal(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _logger.f(_tag(message, tag), error: error, stackTrace: stackTrace);

  static String _tag(String msg, String? tag) =>
      tag != null ? '[$tag] $msg' : msg;
}

class _ReleaseOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    final crashlytics = FirebaseCrashlytics.instance;
    final message = event.lines.join('\n');

    if (event.level.index >= Level.fatal.index) {
      crashlytics.recordError(
        message,
        null,
        reason: 'fatal log',
        fatal: true,
      );
    } else if (event.level.index >= Level.error.index) {
      crashlytics.recordError(message, null, reason: 'error log');
    } else if (event.level.index >= Level.warning.index) {
      crashlytics.log(message);
    }
  }
}
