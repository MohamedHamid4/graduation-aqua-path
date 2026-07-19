import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/parking_spot.dart';

abstract class ParkingSpotRepository {
  /// Live list of verified + organization-approved parking spots — every
  /// resident's map watches this to render the "official parking"
  /// markers. The organization map also uses it as the "live" layer,
  /// merged with [watchAllSpots] for the management list.
  Stream<Either<Failure, List<ParkingSpot>>> watchVerifiedSpots();

  /// Every spot regardless of verification/approval state, for the
  /// organization's parking-management screen.
  Stream<Either<Failure, List<ParkingSpot>>> watchAllSpots();

  /// Called by the driver app whenever a truck is observed to have just
  /// stopped moving. Finds the nearest existing spot within
  /// [kParkingRadiusMeters]; if one exists its stop count is incremented
  /// (and it's promoted to verified once the threshold is reached),
  /// otherwise a new candidate spot is created with a stop count of 1.
  Future<Either<Failure, Unit>> registerStop({
    required double latitude,
    required double longitude,
    required String driverUid,
    required String areaName,
  });

  // ── Organization-only actions (enforced by Firestore rules) ─────────
  Future<Either<Failure, Unit>> approveSpot(String spotId);

  Future<Either<Failure, Unit>> disableSpot(String spotId);

  Future<Either<Failure, Unit>> editSpot(
    String spotId, {
    String? areaName,
    double? latitude,
    double? longitude,
  });

  Future<Either<Failure, Unit>> deleteSpot(String spotId);
}
