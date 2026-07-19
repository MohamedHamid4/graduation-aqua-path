import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/truck.dart';

abstract class TruckRepository {
  Stream<Either<Failure, List<Truck>>> getTrucksStream();
  Future<Either<Failure, Truck>> getTruckById(String id);
  Future<Either<Failure, void>> updateTruckLocation(
    String truckId,
    double lat,
    double lng,
  );

  /// Creates/resumes a truck's live-tracking document when a driver starts
  /// a trip. Safe to call even if the truck document doesn't exist yet.
  Future<Either<Failure, void>> startTrip({
    required String truckId,
    required String driverName,
    required String routeName,
    required double lat,
    required double lng,
    required double capacity,
    String? activeRouteId,
  });

  /// Marks a truck idle when the driver ends a trip.
  Future<Either<Failure, void>> endTrip(String truckId);

  /// Pauses an in-progress trip (e.g. driver break) without releasing the
  /// assigned route.
  Future<Either<Failure, void>> pauseTrip(String truckId);

  /// Resumes a paused trip.
  Future<Either<Failure, void>> resumeTrip(String truckId);

  /// Records a driver-confirmed delivered quantity against the truck's
  /// remaining load and running totals.
  Future<Either<Failure, void>> recordDelivery({
    required String truckId,
    required double liters,
  });
}
