import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity_service.dart';
import '../datasources/truck_firebase_source.dart';
import '../datasources/truck_local_source.dart';
import '../models/truck_dto.dart';
import '../../domain/entities/truck.dart';
import '../../domain/repositories/truck_repository.dart';

class TruckRepositoryImpl implements TruckRepository {
  final TruckFirebaseSource firebaseSource;
  final TruckLocalSource localSource;
  final ConnectivityService connectivityService;

  TruckRepositoryImpl({
    required this.firebaseSource,
    required this.localSource,
    required this.connectivityService,
  });

  @override
  Stream<Either<Failure, List<Truck>>> getTrucksStream() async* {
    final connected = await connectivityService.isConnected;

    if (connected) {
      yield* firebaseSource.getTrucksStream().map((dtos) {
        // Persist to local cache while online
        localSource.cacheTrucks(dtos.map((d) => d.toMap()).toList());
        localSource.updateCacheTime();
        return Right<Failure, List<Truck>>(
          dtos.map((dto) => dto.toDomain()).toList(),
        );
      });
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
          yield* firebaseSource.getTrucksStream().map((dtos) {
            localSource.cacheTrucks(dtos.map((d) => d.toMap()).toList());
            localSource.updateCacheTime();
            return Right<Failure, List<Truck>>(
              dtos.map((dto) => dto.toDomain()).toList(),
            );
          });
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
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
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
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
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
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> endTrip(String truckId) async {
    try {
      await firebaseSource.endTrip(truckId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> pauseTrip(String truckId) async {
    try {
      await firebaseSource.pauseTrip(truckId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resumeTrip(String truckId) async {
    try {
      await firebaseSource.resumeTrip(truckId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
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
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
