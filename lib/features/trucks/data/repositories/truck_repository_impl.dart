import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity_service.dart';
import '../datasources/truck_firebase_source.dart';
import '../datasources/truck_local_source.dart';
import '../models/truck_dto.dart';
import '../../domain/entities/truck.dart';
import '../../domain/repositories/truck_repository.dart';

const _tag = 'Truck';

class TruckRepositoryImpl implements TruckRepository {
  final TruckFirebaseSource firebaseSource;
  final TruckLocalSource localSource;
  final ConnectivityService connectivityService;

  TruckRepositoryImpl({
    required this.firebaseSource,
    required this.localSource,
    required this.connectivityService,
  });

  /// Wraps the live Firestore trucks stream so a stream ERROR (e.g.
  /// permission-denied) becomes a typed Left(Failure) data event instead
  /// of propagating raw and bypassing Either-wrapping — see
  /// FailureMapper doc comment for why a bare `.map()` isn't enough.
  Stream<Either<Failure, List<Truck>>> _watchLive() {
    return FailureMapper.mapStream(
      firebaseSource.getTrucksStream,
      (dtos) {
        localSource.cacheTrucks(dtos.map((d) => d.toMap()).toList());
        localSource.updateCacheTime();
        return dtos.map((dto) => dto.toDomain()).toList();
      },
      tag: _tag,
    );
  }

  @override
  Stream<Either<Failure, List<Truck>>> getTrucksStream() async* {
    final connected = await connectivityService.isConnected;

    if (connected) {
      yield* _watchLive();
    } else {
      // M-6: Offline — emit cache immediately, then watch for reconnection and
      // switch to the live Firebase stream without requiring a screen reload.
      final cachedMaps = localSource.getCachedTrucks();
      final trucks = cachedMaps
          .map((m) => TruckDto.fromMap(m['id'] as String? ?? '', m))
          .map((dto) => dto.toDomain())
          .toList();
      yield Right<Failure, List<Truck>>(trucks);

      await for (final isOnline in connectivityService.onConnectivityChanged) {
        if (isOnline) {
          yield* _watchLive();
          return;
        }
      }
    }
  }

  @override
  Future<Either<Failure, Truck>> getTruckById(String id) async {
    try {
      final dto = await firebaseSource.getTruckById(id);
      if (dto == null) {
        return const Left(NotFoundFailure('الشاحنة غير موجودة'));
      }
      return Right(dto.toDomain());
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, void>> updateTruckLocation(
    String truckId,
    double lat,
    double lng,
  ) async {
    try {
      await firebaseSource.updateTruckLocation(truckId, lat, lng);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, void>> startTrip({
    required String truckId,
    required String driverName,
    required String routeName,
    required double lat,
    required double lng,
    required double capacity,
    String? activeRouteId,
  }) async {
    try {
      await firebaseSource.startTrip(
        truckId: truckId,
        driverName: driverName,
        routeName: routeName,
        lat: lat,
        lng: lng,
        capacity: capacity,
        activeRouteId: activeRouteId,
      );
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, void>> endTrip(String truckId) async {
    try {
      await firebaseSource.endTrip(truckId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, void>> pauseTrip(String truckId) async {
    try {
      await firebaseSource.pauseTrip(truckId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, void>> resumeTrip(String truckId) async {
    try {
      await firebaseSource.resumeTrip(truckId);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, void>> recordDelivery({
    required String truckId,
    required double liters,
  }) async {
    try {
      await firebaseSource.recordDelivery(truckId: truckId, liters: liters);
      return const Right(null);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }
}
