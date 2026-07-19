import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/offline/offline_write_queue_service.dart';
import '../../../../shared/models/household_model.dart';
import '../../domain/repositories/household_repository.dart';
import '../datasources/household_firebase_source.dart';

class HouseholdRepositoryImpl implements HouseholdRepository {
  final HouseholdFirebaseSource _source;
  final ConnectivityService _connectivity;
  final OfflineWriteQueueService _offlineQueue;

  HouseholdRepositoryImpl(
    this._source, {
    required ConnectivityService connectivity,
    required OfflineWriteQueueService offlineQueue,
  })  : _connectivity = connectivity,
        _offlineQueue = offlineQueue;

  @override
  Future<Either<Failure, Unit>> saveHousehold({
    required String uid,
    required HouseholdModel household,
  }) async {
    // Offline: queue the write instead of failing outright. This is
    // exactly the "household registration fails hard with no
    // connectivity" gap the review flagged — a resident filling the
    // registration form with a weak/no signal now has their data queued
    // and safely written the moment the app is back online, rather than
    // losing the form submission entirely.
    if (!await _connectivity.isConnected) {
      await _offlineQueue.enqueue(
        collection: 'households',
        docId: uid,
        data: household.toMap(),
      );
      AppLogger.info(
        'Household save queued offline for uid=$uid',
        tag: 'Household',
      );
      return const Right(unit);
    }

    try {
      await _source.saveHousehold(uid, household);
      AppLogger.info('Household saved for uid=$uid', tag: 'Household');
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error(
        'Household save failed',
        tag: 'Household',
        error: e,
        stackTrace: st,
      );
      return const Left(
        ServerFailure('فشل حفظ البيانات. تحقق من اتصالك وحاول مجدداً.'),
      );
    }
  }

  @override
  Future<Either<Failure, HouseholdModel?>> getHousehold(String uid) async {
    try {
      final household = await _source.getHousehold(uid);
      return Right(household);
    } catch (e, st) {
      AppLogger.error(
        'getHousehold failed',
        tag: 'Household',
        error: e,
        stackTrace: st,
      );
      return const Left(ServerFailure('تعذّر تحميل بيانات الأسرة'));
    }
  }
}
