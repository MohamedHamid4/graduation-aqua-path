import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity_service.dart';
import '../datasources/water_delivery_firebase_source.dart';
import '../models/water_delivery_dto.dart';
import '../../domain/entities/water_delivery.dart';
import '../../domain/repositories/water_delivery_repository.dart';

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
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  @override
  Stream<Either<Failure, List<WaterDelivery>>> getAreaDeliveriesStream(
    String areaName,
  ) {
    return firebaseSource.getAreaDeliveriesStream(areaName).map(
          (dtos) => Right<Failure, List<WaterDelivery>>(
            dtos.map((d) => d.toDomain()).toList(),
          ),
        );
  }

  @override
  Stream<Either<Failure, double>> getAreaTotalStream(String areaName) {
    return firebaseSource.getAreaDeliveriesStream(areaName).map((dtos) {
      final total = dtos.fold(0.0, (prev, d) => prev + d.amountLiters);
      return Right<Failure, double>(total);
    });
  }

  @override
  Future<Either<Failure, Unit>> acknowledgeDelivery({
    required String deliveryId,
    required String residentUid,
  }) async {
    try {
      await firebaseSource.acknowledgeDelivery(deliveryId, residentUid);
      return const Right(unit);
    } on Exception catch (e) {
      return Left(ServerFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
