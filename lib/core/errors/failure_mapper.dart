import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../logging/app_logger.dart';
import 'failures.dart';

/// Turns a caught exception into the right [Failure] subtype — the single
/// place that decides "is this actually a network problem, or something
/// else (permission-denied, missing index, bad data) that got caught by a
/// broad try/catch and would otherwise be shown to the user as a fake
/// connection error?"
///
/// Repositories should call [FailureMapper.map] from their catch block
/// instead of hand-wrapping `e.toString()` into a [ServerFailure] — that
/// pattern silently discards the real Firebase error code and the UI ends
/// up telling the user to "check your internet" for e.g. a Firestore rules
/// rejection.
abstract final class FailureMapper {
  static Failure map(
    Object error,
    StackTrace stackTrace, {
    required String tag,
  }) {
    if (error is FirebaseException) {
      AppLogger.error(
        'Firebase error [${error.plugin}/${error.code}]: ${error.message}',
        tag: tag,
        error: error,
        stackTrace: stackTrace,
      );
      return _fromFirebaseCode(error);
    }

    AppLogger.error(
      'Unhandled error: $error',
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
    return UnknownFailure(error.toString());
  }

  static Failure _fromFirebaseCode(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return PermissionFailure(error.code);

      // Genuine connectivity/reachability problems — this is the only
      // case that should ever show a "check your internet" message.
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return const NetworkFailure();

      // Firestore query needs a composite index — the console link is in
      // error.message, surface it so it can actually be diagnosed instead
      // of being replaced by a generic string.
      case 'failed-precondition':
        return ServerFailure(
          error.message ?? 'يتطلب هذا الاستعلام إعداداً إضافياً في الخادم.',
        );

      default:
        return ServerFailure(
          error.message ?? 'حدث خطأ في الخادم (${error.code}).',
        );
    }
  }
}
