import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/driver_profile.dart';
import '../entities/driver_route.dart';

/// Abstract contract for everything driver-specific: profile registration,
/// role lookup, and the day's assigned routes.
///
/// Live location broadcasting deliberately does NOT live here — that's
/// [TruckRepository.startTrip] / [updateTruckLocation] / [endTrip], since
/// position updates write to the same `trucks` collection the resident
/// side already streams from. Keeping it there means one write path, no
/// duplicated Firestore logic between driver and resident features.
abstract class DriverRepository {
  /// `true` if a driver profile document exists for this UID. Used by the
  /// router/splash screen to branch between the resident and driver flows
  /// after a shared Firebase Auth sign-in.
  Future<bool> isDriver(String uid);

  Future<Either<Failure, Unit>> registerDriverProfile(DriverProfile profile);

  Future<Either<Failure, DriverProfile?>> getDriverProfile(String uid);

  /// Live stream of today's assigned routes for a driver, ordered by
  /// scheduled time.
  Stream<Either<Failure, List<DriverRoute>>> watchRoutesForDriver(
    String driverUid,
  );

  /// Live stream of every route scheduled for a given area, regardless of
  /// assigned driver — the resident-facing counterpart to
  /// [watchRoutesForDriver], used to show upcoming distribution visits on
  /// the resident's own schedule screen.
  Stream<Either<Failure, List<DriverRoute>>> watchRoutesForArea(
    String areaName,
  );

  Future<Either<Failure, Unit>> updateRouteStatus({
    required String routeId,
    required String status,
  });

  /// Updates the driver's profile-picture URL after a successful upload to
  /// Firebase Storage at `driver_profile_pictures/{uid}` (see
  /// `firebase/storage.rules` — only the owning driver may write that
  /// path). This method only persists the resulting download URL; the
  /// actual upload is a Storage operation the presentation layer performs
  /// with `firebase_storage` before calling this.
  Future<Either<Failure, Unit>> updateProfilePicture({
    required String uid,
    required String downloadUrl,
  });
}
