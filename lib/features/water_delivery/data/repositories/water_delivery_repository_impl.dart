import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity_service.dart';
import '../datasources/water_delivery_firebase_source.dart';
import '../models/water_delivery_dto.dart';
import '../../domain/entities/water_delivery.dart';
import '../../domain/repositories/water_delivery_repository.dart';

const _tag = 'WaterDelivery';

class WaterDeliveryRepositoryImpl implements WaterDeliveryRepository {
  final WaterDeliveryFirebaseSource firebaseSource;
  final ConnectivityService connectivityService;

  WaterDeliveryRepositoryImpl({
    required this.firebaseSource,
    required this.connectivityService,
  });

  @override
  Future<Either<Failure, Unit>> confirmDeliveryByDriver({
    required double amountLiters,
    required String driverUid,
    required String truckId,
    required String areaName,
    double? driverLat,
    double? driverLng,
  }) async {
    if (!await connectivityService.isConnected) {
      return const Left(NetworkFailure('لا يوجد اتصال بالإنترنت'));
    }

    try {
      final dto = WaterDeliveryDto(
        deliveryId: '',
        driverUid: driverUid,
        truckId: truckId,
        tripId: '',
        amountLiters: amountLiters,
        areaName: areaName,
        driverLat: driverLat,
        driverLng: driverLng,
        createdAt: DateTime.now(),
      );

      await firebaseSource.submitDriverDeliveryTransaction(dto);
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  /// Wraps the raw Firestore snapshot stream so an error event (e.g. a
  /// `permission-denied` from a security-rule rejection, or a missing
  /// composite index) becomes a typed `Left(Failure)` data event instead
  /// of propagating as a raw stream error — a bare `.map()` on a Stream
  /// only transforms data events, so error events would otherwise bypass
  /// the Either wrapping entirely and reach the UI as an untyped
  /// exception with no classification.
  Stream<Either<Failure, List<WaterDeliveryDto>>> _watchDeliveries(
    String areaName,
  ) {
    return FailureMapper.mapStream(
      () => firebaseSource.getAreaDeliveriesStream(areaName),
      (dtos) => dtos,
      tag: _tag,
    );
  }

  @override
  Stream<Either<Failure, List<WaterDelivery>>> getAreaDeliveriesStream(
    String areaName,
  ) {
    return _watchDeliveries(areaName).map(
      (either) => either.map((dtos) => dtos.map((d) => d.toDomain()).toList()),
    );
  }

  @override
  Stream<Either<Failure, double>> getAreaTotalStream(String areaName) {
    return _watchDeliveries(areaName).map(
      (either) => either.map(
        (dtos) => dtos.fold(0.0, (prev, d) => prev + d.amountLiters),
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> acknowledgeDelivery({
    required String deliveryId,
    required String residentUid,
  }) async {
    try {
      await firebaseSource.acknowledgeDelivery(deliveryId, residentUid);
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }
}
