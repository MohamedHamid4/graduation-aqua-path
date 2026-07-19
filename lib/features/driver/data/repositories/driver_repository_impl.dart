import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/offline/offline_write_queue_service.dart';
import '../../domain/entities/driver_profile.dart';
import '../../domain/entities/driver_route.dart';
import '../../domain/repositories/driver_repository.dart';
import '../datasources/driver_firebase_source.dart';

class DriverRepositoryImpl implements DriverRepository {
  final DriverFirebaseSource _source;
  final ConnectivityService _connectivity;
  final OfflineWriteQueueService _offlineQueue;

  DriverRepositoryImpl(
    this._source, {
    required ConnectivityService connectivity,
    required OfflineWriteQueueService offlineQueue,
  })  : _connectivity = connectivity,
        _offlineQueue = offlineQueue;

  @override
  Future<bool> isDriver(String uid) async {
    try {
      return await _source.isDriver(uid);
    } catch (e) {
      // Fail closed: if we can't confirm driver status, treat as a
      // resident rather than risk exposing driver-only screens.
      AppLogger.warning('isDriver check failed for uid=$uid', tag: 'Driver');
      return false;
    }
  }

  @override
  Future<Either<Failure, Unit>> registerDriverProfile(
    DriverProfile profile,
  ) async {
    // Same reasoning as HouseholdRepositoryImpl.saveHousehold: a driver
    // completing registration with weak/no connectivity gets the write
    // queued instead of losing the form.
    if (!await _connectivity.isConnected) {
      await _offlineQueue.enqueue(
        collection: 'drivers',
        docId: profile.uid,
        data: profile.toMap(),
      );
      AppLogger.info(
        'Driver profile registration queued offline: ${profile.uid}',
        tag: 'Driver',
      );
      return const Right(unit);
    }

    try {
      await _source.registerDriverProfile(profile);
      AppLogger.info(
        'Driver profile registered: ${profile.uid}',
        tag: 'Driver',
      );
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error(
        'Driver registration failed',
        tag: 'Driver',
        error: e,
        stackTrace: st,
      );
      return const Left(ServerFailure('فشل تسجيل بيانات السائق'));
    }
  }

  @override
  Future<Either<Failure, DriverProfile?>> getDriverProfile(
    String uid,
  ) async {
    try {
      final profile = await _source.getDriverProfile(uid);
      return Right(profile);
    } catch (e, st) {
      AppLogger.error(
        'getDriverProfile failed',
        tag: 'Driver',
        error: e,
        stackTrace: st,
      );
      return const Left(ServerFailure('تعذّر تحميل بيانات السائق'));
    }
  }

  @override
  Stream<Either<Failure, List<DriverRoute>>> watchRoutesForDriver(
    String driverUid,
  ) {
    try {
      return _source.watchRoutesForDriver(driverUid).map(
            (routes) => Right<Failure, List<DriverRoute>>(routes),
          );
    } catch (e) {
      return Stream.value(
        Left(ServerFailure(e.toString())),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> updateRouteStatus({
    required String routeId,
    required String status,
  }) async {
    try {
      await _source.updateRouteStatus(routeId: routeId, status: status);
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error(
        'updateRouteStatus failed',
        tag: 'Driver',
        error: e,
        stackTrace: st,
      );
      return const Left(ServerFailure('فشل تحديث حالة الرحلة'));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateProfilePicture({
    required String uid,
    required String downloadUrl,
  }) async {
    try {
      await _source.updateProfilePicture(uid, downloadUrl);
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error(
        'updateProfilePicture failed',
        tag: 'Driver',
        error: e,
        stackTrace: st,
      );
      return const Left(ServerFailure('فشل تحديث الصورة الشخصية'));
    }
  }
}
