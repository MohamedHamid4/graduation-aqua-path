import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../shared/models/household_model.dart';
import '../../../driver/domain/entities/driver_profile.dart';
import '../../../driver/domain/entities/driver_route.dart';
import '../../domain/entities/operations_report.dart';
import '../../domain/entities/org_notification.dart';
import '../../domain/entities/organization_profile.dart';
import '../../domain/entities/service_area.dart';
import '../../domain/repositories/organization_repository.dart';
import '../datasources/organization_firebase_source.dart';

const _tag = 'Organization';

class OrganizationRepositoryImpl implements OrganizationRepository {
  final OrganizationFirebaseSource _source;

  OrganizationRepositoryImpl(this._source);

  @override
  Future<Either<Failure, OrganizationProfile?>> getOwnProfile(
      String uid) async {
    try {
      return Right(await _source.getOwnProfile(uid));
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Stream<Either<Failure, List<DriverProfile>>> watchAllDrivers() =>
      FailureMapper.mapStream(_source.watchAllDrivers, (d) => d, tag: _tag);

  @override
  Future<Either<Failure, Unit>> setDriverActive({
    required String driverUid,
    required bool active,
  }) async {
    try {
      await _source.setDriverStatus(driverUid, active ? 'active' : 'inactive');
      AppLogger.info(
        'Driver $driverUid set to ${active ? 'active' : 'inactive'}',
        tag: 'Organization',
      );
      return const Right(unit);
    } on FirebaseFunctionsException catch (e, st) {
      AppLogger.error('setDriverActive callable failed [${e.code}]',
          tag: _tag, error: e, stackTrace: st);
      return Left(
          ServerFailure('تعذّر تغيير صلاحية السائق: ${e.message ?? e.code}'));
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, Unit>> assignDriverToArea({
    required String driverUid,
    required String areaId,
  }) async {
    try {
      await _source.assignDriverToArea(driverUid, areaId);
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateTruckInfo({
    required String driverUid,
    required String truckPlateNumber,
    required double truckCapacity,
  }) async {
    try {
      await _source.updateTruckInfo(
        driverUid,
        truckPlateNumber: truckPlateNumber,
        truckCapacity: truckCapacity,
      );
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Stream<Either<Failure, List<HouseholdModel>>> watchAllHouseholds() =>
      FailureMapper.mapStream(_source.watchAllHouseholds, (h) => h, tag: _tag);

  @override
  Stream<Either<Failure, List<ServiceArea>>> watchAllAreas() =>
      FailureMapper.mapStream(_source.watchAllAreas, (a) => a, tag: _tag);

  @override
  Future<Either<Failure, Unit>> upsertArea(ServiceArea area) async {
    try {
      await _source.upsertArea(area);
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteArea(String areaId) async {
    try {
      await _source.deleteArea(areaId);
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  String newAreaId() => _source.newAreaId();

  @override
  Stream<Either<Failure, List<DriverRoute>>> watchAllRoutes() =>
      FailureMapper.mapStream(_source.watchAllRoutes, (r) => r, tag: _tag);

  @override
  Future<Either<Failure, Unit>> createRoute(DriverRoute route) async {
    try {
      await _source.createRoute(route);
      AppLogger.info('Route created for driver ${route.driverUid}',
          tag: _tag);
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteRoute(String routeId) async {
    try {
      await _source.deleteRoute(routeId);
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, OperationsReport>> buildReport({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      final trucks = await _source.fetchAllTrucksOnce();
      final drivers = await _source.fetchAllDriversOnce();
      final routes = await _source.fetchRoutesInRange(periodStart, periodEnd);
      final deliveries =
          await _source.fetchDeliveriesInRange(periodStart, periodEnd);

      final activeDrivers =
          drivers.where((d) => d['status'] == 'active').length;
      final activeTrucks = trucks.where((t) => t['status'] == 'active').length;
      final completedTrips =
          routes.where((r) => r['status'] == 'completed').length;

      final driverNames = <String, String>{};
      for (final d in drivers) {
        final uid = d['id'] as String? ?? '';
        if (uid.isEmpty) continue;
        final first = d['firstName'] as String? ?? '';
        final last = d['lastName'] as String? ?? '';
        final combined = '$first $last'.trim();
        driverNames[uid] =
            combined.isNotEmpty ? combined : (d['fullName'] as String? ?? uid);
      }

      // Everything below is now scoped to [periodStart, periodEnd] via
      // the water_deliveries query — this is the fix for the report
      // previously showing the same "total liters" figure regardless of
      // whether a daily, weekly, or monthly period was requested.
      double totalLiters = 0;
      final litersByDriver = <String, double>{};
      final litersByArea = <String, double>{};
      final deliveriesByArea = <String, int>{};

      for (final delivery in deliveries) {
        final amount = (delivery['amountLiters'] as num?)?.toDouble() ?? 0;
        final driverUid = delivery['driverUid'] as String? ?? '';
        final area = (delivery['areaName'] as String?)?.trim();
        final areaLabel = (area == null || area.isEmpty) ? 'غير محدد' : area;

        totalLiters += amount;
        if (driverUid.isNotEmpty) {
          litersByDriver[driverUid] = (litersByDriver[driverUid] ?? 0) + amount;
        }
        litersByArea[areaLabel] = (litersByArea[areaLabel] ?? 0) + amount;
        deliveriesByArea[areaLabel] = (deliveriesByArea[areaLabel] ?? 0) + 1;
      }

      return Right(OperationsReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        activeDrivers: activeDrivers,
        totalDrivers: drivers.length,
        activeTrucks: activeTrucks,
        totalTrucks: trucks.length,
        completedTrips: completedTrips,
        totalLitersDelivered: totalLiters,
        deliveriesByArea: deliveriesByArea,
        litersByDriver: litersByDriver,
        litersByArea: litersByArea,
        driverNames: driverNames,
      ));
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Future<Either<Failure, Unit>> sendNotification(
      OrgNotification notification) async {
    try {
      await _source.sendNotification(notification.toMap());
      AppLogger.info(
        'Notification queued: area=${notification.areaName ?? "all"}',
        tag: _tag,
      );
      return const Right(unit);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Stream<Either<Failure, List<OrgNotification>>> watchNotificationHistory() =>
      FailureMapper.mapStream(
        _source.watchNotificationHistory,
        (rows) => rows
            .map((r) => OrgNotification.fromMap(r['id'] as String, r))
            .toList(),
        tag: _tag,
      );
}
