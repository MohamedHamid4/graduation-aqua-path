import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
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

  /// Wraps a raw data-source stream (e.g. a Firestore `.snapshots()` map)
  /// so BOTH failure modes become a typed `Left(Failure)` data event
  /// instead of an uncaught/unclassified exception:
  ///  - a synchronous throw from calling [source] itself (e.g. a
  ///    misconfigured client, or in tests, a mocked method stubbed with
  ///    `thenThrow`) — caught here since a bare `.transform()` never sees
  ///    an exception thrown before the Stream is even obtained;
  ///  - an async error EVENT emitted by the stream once subscribed — a
  ///    bare `.map()` only transforms data events, so this would
  ///    otherwise bypass Either-wrapping entirely.
  /// [source] is a zero-arg function (not the stream itself) precisely so
  /// the first failure mode can be caught at all.
  static Stream<Either<Failure, T>> mapStream<S, T>(
    Stream<S> Function() source,
    T Function(S) transform, {
    required String tag,
  }) {
    try {
      return source().transform(
        StreamTransformer<S, Either<Failure, T>>.fromHandlers(
          handleData: (data, sink) => sink.add(Right(transform(data))),
          handleError: (error, stackTrace, sink) =>
              sink.add(Left(map(error, stackTrace, tag: tag))),
        ),
      );
    } catch (e, st) {
      return Stream.value(Left(map(e, st, tag: tag)));
    }
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
