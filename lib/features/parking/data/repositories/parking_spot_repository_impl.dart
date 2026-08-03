import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/parking_spot.dart';
import '../../domain/repositories/parking_spot_repository.dart';
import '../datasources/parking_spot_firebase_source.dart';

const _tag = 'ParkingSpot';

class ParkingSpotRepositoryImpl implements ParkingSpotRepository {
  final ParkingSpotFirebaseSource _source;

  ParkingSpotRepositoryImpl(this._source);

  @override
  Stream<Either<Failure, List<ParkingSpot>>> watchVerifiedSpots() =>
      FailureMapper.mapStream(
        _source.watchVerifiedSpots,
        (dtos) => dtos.map((dto) => dto.toDomain()).toList(),
        tag: _tag,
      );

  @override
  Stream<Either<Failure, List<ParkingSpot>>> watchAllSpots() =>
      FailureMapper.mapStream(
        _source.watchAllSpots,
        (dtos) => dtos.map((dto) => dto.toDomain()).toList(),
        tag: _tag,
      );

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
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, Unit>> approveSpot(String spotId) async {
    try {
      await _source.setApprovalStatus(spotId, 'approved');
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, Unit>> disableSpot(String spotId) async {
    try {
      await _source.setApprovalStatus(spotId, 'disabled');
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
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
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteSpot(String spotId) async {
    try {
      await _source.deleteSpot(spotId);
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }
}
