import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../shared/models/household_model.dart';
import '../../../driver/domain/entities/driver_profile.dart';
import '../../../driver/domain/entities/driver_route.dart';
import '../entities/operations_report.dart';
import '../entities/org_notification.dart';
import '../entities/organization_profile.dart';
import '../entities/service_area.dart';

/// The Organization role's data contract. Every method here assumes the
/// caller already carries the `organization` custom claim — enforcement
/// lives in Firestore rules, not in this class, but every write path here
/// exists *because* an organization-only rule allows it.
abstract class OrganizationRepository {
  Future<Either<Failure, OrganizationProfile?>> getOwnProfile(String uid);

  // ── Driver management ────────────────────────────────────────────────
  Stream<Either<Failure, List<DriverProfile>>> watchAllDrivers();

  Future<Either<Failure, Unit>> setDriverActive({
    required String driverUid,
    required bool active,
  });

  Future<Either<Failure, Unit>> assignDriverToArea({
    required String driverUid,
    required String areaId,
  });

  /// Edits a truck's static attributes (plate number, capacity) on the
  /// owning driver's profile — `drivers/{uid}.truckPlateNumber` /
  /// `.truckCapacity`. This is the "assign trucks" organization
  /// capability: trucks themselves have no independent identity in the
  /// schema (a `trucks/{uid}` document is created automatically the
  /// first time its driver starts a trip, keyed by the same uid as
  /// `drivers/{uid}`), so "assigning a truck" means setting which
  /// physical vehicle's plate/capacity is recorded against a driver.
  Future<Either<Failure, Unit>> updateTruckInfo({
    required String driverUid,
    required String truckPlateNumber,
    required double truckCapacity,
  });

  // ── Resident (household) oversight — read-only ─────────────────────────
  Stream<Either<Failure, List<HouseholdModel>>> watchAllHouseholds();

  // ── Area management ─────────────────────────────────────────────────
  Stream<Either<Failure, List<ServiceArea>>> watchAllAreas();

  Future<Either<Failure, Unit>> upsertArea(ServiceArea area);

  Future<Either<Failure, Unit>> deleteArea(String areaId);

  /// A fresh, never-used Firestore document ID for a new area — callers
  /// need this before the first [upsertArea] call for a brand-new area
  /// (there's no separate "create" vs "update" method; both go through
  /// the same set-with-merge write, keyed by an ID the caller already
  /// has).
  String newAreaId();

  // ── Work schedule / route management ────────────────────────────────
  Stream<Either<Failure, List<DriverRoute>>> watchAllRoutes();

  Future<Either<Failure, Unit>> createRoute(DriverRoute route);

  Future<Either<Failure, Unit>> deleteRoute(String routeId);

  // ── Reports & statistics ────────────────────────────────────────────
  /// Builds an aggregated report by scanning current driver/truck/route
  /// state — see [OperationsReport] doc comment for the v1/roadmap note
  /// on server-side aggregation.
  Future<Either<Failure, OperationsReport>> buildReport({
    required DateTime periodStart,
    required DateTime periodEnd,
  });

  // ── Notifications ────────────────────────────────────────────────────
  /// Writes the notification doc; `onNotificationCreated` (Cloud
  /// Function) picks it up and fans it out via FCM to the target area's
  /// topic, or every area's topic if [OrgNotification.areaName] is null.
  Future<Either<Failure, Unit>> sendNotification(OrgNotification notification);

  Stream<Either<Failure, List<OrgNotification>>> watchNotificationHistory();
}
