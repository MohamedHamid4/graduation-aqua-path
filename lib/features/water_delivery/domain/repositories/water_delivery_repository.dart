import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/water_delivery.dart';

abstract class WaterDeliveryRepository {
  /// Driver confirms a completed delivery. Only callable by the
  /// authenticated driver who owns [truckId] (enforced by Firestore
  /// rules); records the delivered quantity, timestamp, driver location,
  /// and the active route, and decrements the truck's remaining load in
  /// the same transaction.
  Future<Either<Failure, Unit>> confirmDeliveryByDriver({
    required double amountLiters,
    required String driverUid,
    required String truckId,
    required String areaName,
    double? driverLat,
    double? driverLng,
  });

  /// Delivery history for a *service area* — residents see every
  /// delivery recorded for their registered area, not just ones tied to
  /// their own account, since the driver addresses a street, not an
  /// individual household.
  Stream<Either<Failure, List<WaterDelivery>>> getAreaDeliveriesStream(
    String areaName,
  );

  Stream<Either<Failure, double>> getAreaTotalStream(String areaName);

  /// A resident optionally acknowledges receipt of a delivery already
  /// recorded by the driver. This never changes the recorded quantity —
  /// only who has seen/confirmed it.
  Future<Either<Failure, Unit>> acknowledgeDelivery({
    required String deliveryId,
    required String residentUid,
  });
}
