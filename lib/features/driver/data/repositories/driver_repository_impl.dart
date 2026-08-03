import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/offline/offline_write_queue_service.dart';
import '../../domain/entities/driver_profile.dart';
import '../../domain/entities/driver_route.dart';
import '../../domain/repositories/driver_repository.dart';
import '../datasources/driver_firebase_source.dart';

const _tag = 'Driver';

class DriverRepositoryImpl implements DriverRepository {
  final DriverFirebaseSource _source;
  final OfflineWriteQueueService _offlineQueue;

  DriverRepositoryImpl(
    this._source, {
    required OfflineWriteQueueService offlineQueue,
  }) : _offlineQueue = offlineQueue;

  @override
  Future<bool> isDriver(String uid) async {
    try {
      return await _source.isDriver(uid);
    } catch (e) {
      // Fail closed: if we can't confirm driver status, treat as a
      // resident rather than risk exposing driver-only screens.
      AppLogger.warning('isDriver check failed for uid=$uid', tag: _tag);
      return false;
    }
  }

  @override
  Future<Either<Failure, Unit>> registerDriverProfile(
    DriverProfile profile,
  ) async {
    // Attempt the real write first — see HouseholdRepositoryImpl
    // .saveHousehold for why pre-checking connectivity_plus is unsafe
    // (it can misreport offline while Firestore is actually reachable,
    // silently queuing the write and returning fake success). Only a
    // write that itself fails for a genuine connectivity reason gets
    // queued; anything else must be reported as a real failure.
    try {
      await _source.registerDriverProfile(profile);
      AppLogger.info(
        'Driver profile registered: ${profile.uid}',
        tag: _tag,
      );
      return const Right(unit);
    } catch (e, st) {
      final failure = FailureMapper.map(e, st, tag: _tag);
      if (failure is NetworkFailure) {
        await _offlineQueue.enqueue(
          collection: 'drivers',
          docId: profile.uid,
          data: profile.toMap(),
        );
        AppLogger.info(
          'Driver profile registration queued offline: ${profile.uid} '
          '(no connectivity)',
          tag: _tag,
        );
        return const Right(unit);
      }
      return Left(failure);
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
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Stream<Either<Failure, List<DriverRoute>>> watchRoutesForDriver(
    String driverUid,
  ) =>
      FailureMapper.mapStream(
        () => _source.watchRoutesForDriver(driverUid),
        (routes) => routes,
        tag: _tag,
      );

  @override
  Stream<Either<Failure, List<DriverRoute>>> watchRoutesForArea(
    String areaName,
  ) =>
      FailureMapper.mapStream(
        () => _source.watchRoutesForArea(areaName),
        (routes) => routes,
        tag: _tag,
      );

  @override
  Future<Either<Failure, Unit>> updateRouteStatus({
    required String routeId,
    required String status,
  }) async {
    try {
      await _source.updateRouteStatus(routeId: routeId, status: status);
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
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
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }
}
