import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notification_history_repository.dart';
import '../datasources/notification_history_firebase_source.dart';

class NotificationHistoryRepositoryImpl
    implements NotificationHistoryRepository {
  final NotificationHistoryFirebaseSource _source;

  NotificationHistoryRepositoryImpl(this._source);

  @override
  Stream<Either<Failure, List<NotificationItem>>> watchNotifications(
    String uid,
  ) {
    try {
      return _source.watchNotifications(uid).map(
            (items) => Right<Failure, List<NotificationItem>>(items),
          );
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Future<Either<Failure, Unit>> recordReceived({
    required String uid,
    required String messageId,
    required String title,
    required String body,
    required String type,
    String? areaName,
  }) async {
    try {
      await _source.recordReceived(
        uid: uid,
        messageId: messageId,
        title: title,
        body: body,
        type: type,
        areaName: areaName,
      );
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error(
        'recordReceived failed',
        tag: 'NotificationHistory',
        error: e,
        stackTrace: st,
      );
      return const Left(ServerFailure('تعذّر حفظ الإشعار'));
    }
  }

  @override
  Future<Either<Failure, Unit>> markRead({
    required String uid,
    required String itemId,
  }) async {
    try {
      await _source.markRead(uid, itemId);
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error(
        'markRead failed',
        tag: 'NotificationHistory',
        error: e,
        stackTrace: st,
      );
      return const Left(ServerFailure('تعذّر تحديث حالة الإشعار'));
    }
  }

  @override
  Future<Either<Failure, Unit>> markAllRead(String uid) async {
    try {
      await _source.markAllRead(uid);
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error(
        'markAllRead failed',
        tag: 'NotificationHistory',
        error: e,
        stackTrace: st,
      );
      return const Left(ServerFailure('تعذّر تحديث حالة الإشعارات'));
    }
  }
}
