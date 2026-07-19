import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/parking_spot.dart';
import '../../domain/repositories/parking_spot_repository.dart';
import '../datasources/parking_spot_firebase_source.dart';

class ParkingSpotRepositoryImpl implements ParkingSpotRepository {
  final ParkingSpotFirebaseSource _source;

  ParkingSpotRepositoryImpl(this._source);

  @override
  Stream<Either<Failure, List<ParkingSpot>>> watchVerifiedSpots() {
    try {
      return _source.watchVerifiedSpots().map(
            (dtos) => Right<Failure, List<ParkingSpot>>(
              dtos.map((dto) => dto.toDomain()).toList(),
            ),
          );
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Stream<Either<Failure, List<ParkingSpot>>> watchAllSpots() {
    try {
      return _source.watchAllSpots().map(
            (dtos) => Right<Failure, List<ParkingSpot>>(
              dtos.map((dto) => dto.toDomain()).toList(),
            ),
          );
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Future<Either<Failure, Unit>> registerStop({
    required double latitude,
    required double longitude,
    required String driverUid,
    required String areaName,
  }) async {
    try {
      await _source.registerStop(
        latitude: latitude,
        longitude: longitude,
        driverUid: driverUid,
        areaName: areaName,
      );
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error(
        'registerStop failed',
        tag: 'ParkingSpot',
        error: e,
        stackTrace: st,
      );
      return const Left(ServerFailure('فشل تسجيل موقع التوقف'));
    }
  }

  @override
  Future<Either<Failure, Unit>> approveSpot(String spotId) async {
    try {
      await _source.setApprovalStatus(spotId, 'approved');
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('approveSpot failed',
          tag: 'ParkingSpot', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل اعتماد موقع الانتظار'));
    }
  }

  @override
  Future<Either<Failure, Unit>> disableSpot(String spotId) async {
    try {
      await _source.setApprovalStatus(spotId, 'disabled');
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('disableSpot failed',
          tag: 'ParkingSpot', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل تعطيل موقع الانتظار'));
    }
  }

  @override
  Future<Either<Failure, Unit>> editSpot(
    String spotId, {
    String? areaName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final patch = <String, dynamic>{
        if (areaName != null) 'areaName': areaName,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
      if (patch.isEmpty) return const Right(unit);
      await _source.updateSpot(spotId, patch);
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('editSpot failed',
          tag: 'ParkingSpot', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل تعديل موقع الانتظار'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteSpot(String spotId) async {
    try {
      await _source.deleteSpot(spotId);
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('deleteSpot failed',
          tag: 'ParkingSpot', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل حذف موقع الانتظار'));
    }
  }
}
