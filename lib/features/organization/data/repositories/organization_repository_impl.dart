import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';

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

class OrganizationRepositoryImpl implements OrganizationRepository {
  final OrganizationFirebaseSource _source;

  OrganizationRepositoryImpl(this._source);

  @override
  Future<Either<Failure, OrganizationProfile?>> getOwnProfile(
      String uid) async {
    try {
      return Right(await _source.getOwnProfile(uid));
    } catch (e, st) {
      AppLogger.error('getOwnProfile failed',
          tag: 'Organization', error: e, stackTrace: st);
      return const Left(ServerFailure('تعذّر تحميل بيانات المؤسسة'));
    }
  }

  @override
  Stream<Either<Failure, List<DriverProfile>>> watchAllDrivers() {
    try {
      return _source.watchAllDrivers().map(
            (drivers) => Right<Failure, List<DriverProfile>>(drivers),
          );
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

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
          tag: 'Organization', error: e, stackTrace: st);
      return Left(
          ServerFailure('تعذّر تغيير صلاحية السائق: ${e.message ?? e.code}'));
    } catch (e, st) {
      AppLogger.error('setDriverActive failed',
          tag: 'Organization', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل تحديث حالة السائق'));
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
      AppLogger.error('assignDriverToArea failed',
          tag: 'Organization', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل تعيين السائق للمنطقة'));
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
      AppLogger.error('updateTruckInfo failed',
          tag: 'Organization', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل تحديث بيانات الشاحنة'));
    }
  }

  @override
  Stream<Either<Failure, List<HouseholdModel>>> watchAllHouseholds() {
    try {
      return _source.watchAllHouseholds().map(
            (households) => Right<Failure, List<HouseholdModel>>(households),
          );
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Stream<Either<Failure, List<ServiceArea>>> watchAllAreas() {
    try {
      return _source.watchAllAreas().map(
            (areas) => Right<Failure, List<ServiceArea>>(areas),
          );
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Future<Either<Failure, Unit>> upsertArea(ServiceArea area) async {
    try {
      await _source.upsertArea(area);
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('upsertArea failed',
          tag: 'Organization', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل حفظ بيانات المنطقة'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteArea(String areaId) async {
    try {
      await _source.deleteArea(areaId);
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('deleteArea failed',
          tag: 'Organization', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل حذف المنطقة'));
    }
  }

  @override
  String newAreaId() => _source.newAreaId();

  @override
  Stream<Either<Failure, List<DriverRoute>>> watchAllRoutes() {
    try {
      return _source.watchAllRoutes().map(
            (routes) => Right<Failure, List<DriverRoute>>(routes),
          );
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }

  @override
  Future<Either<Failure, Unit>> createRoute(DriverRoute route) async {
    try {
      await _source.createRoute(route);
      AppLogger.info('Route created for driver ${route.driverUid}',
          tag: 'Organization');
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('createRoute failed',
          tag: 'Organization', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل إنشاء جدول الرحلة'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteRoute(String routeId) async {
    try {
      await _source.deleteRoute(routeId);
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('deleteRoute failed',
          tag: 'Organization', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل حذف الرحلة'));
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
      AppLogger.error('buildReport failed',
          tag: 'Organization', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل إنشاء التقرير'));
    }
  }

  @override
  Future<Either<Failure, Unit>> sendNotification(
      OrgNotification notification) async {
    try {
      await _source.sendNotification(notification.toMap());
      AppLogger.info(
        'Notification queued: area=${notification.areaName ?? "all"}',
        tag: 'Organization',
      );
      return const Right(unit);
    } catch (e, st) {
      AppLogger.error('sendNotification failed',
          tag: 'Organization', error: e, stackTrace: st);
      return const Left(ServerFailure('فشل إرسال الإشعار'));
    }
  }

  @override
  Stream<Either<Failure, List<OrgNotification>>> watchNotificationHistory() {
    try {
      return _source.watchNotificationHistory().map(
            (rows) => Right<Failure, List<OrgNotification>>(
              rows
                  .map((r) => OrgNotification.fromMap(r['id'] as String, r))
                  .toList(),
            ),
          );
    } catch (e) {
      return Stream.value(Left(ServerFailure(e.toString())));
    }
  }
}
