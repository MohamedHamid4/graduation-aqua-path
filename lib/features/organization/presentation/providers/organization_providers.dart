import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../shared/models/household_model.dart';
import '../../../driver/domain/entities/driver_profile.dart';
import '../../../driver/domain/entities/driver_route.dart';
import '../../domain/entities/operations_report.dart';
import '../../domain/entities/org_notification.dart';
import '../../domain/entities/service_area.dart';
import '../../domain/repositories/organization_repository.dart';

OrganizationRepository get _orgRepo => GetIt.I<OrganizationRepository>();

final allDriversProvider = StreamProvider<List<DriverProfile>>((ref) {
  return _orgRepo.watchAllDrivers().map(
        (either) => either.fold((_) => <DriverProfile>[], (d) => d),
      );
});

final allHouseholdsProvider = StreamProvider<List<HouseholdModel>>((ref) {
  return _orgRepo.watchAllHouseholds().map(
        (either) => either.fold((_) => <HouseholdModel>[], (h) => h),
      );
});

final allAreasProvider = StreamProvider<List<ServiceArea>>((ref) {
  return _orgRepo.watchAllAreas().map(
        (either) => either.fold((_) => <ServiceArea>[], (a) => a),
      );
});

final allRoutesProvider = StreamProvider<List<DriverRoute>>((ref) {
  return _orgRepo.watchAllRoutes().map(
        (either) => either.fold((_) => <DriverRoute>[], (r) => r),
      );
});

final notificationHistoryProvider =
    StreamProvider<List<OrgNotification>>((ref) {
  return _orgRepo.watchNotificationHistory().map(
        (either) => either.fold((_) => <OrgNotification>[], (n) => n),
      );
});

/// Today's operations report — the dashboard's headline numbers. See
/// [OperationsReport] doc comment for the client-side-aggregation note.
final todayReportProvider =
    FutureProvider.autoDispose<OperationsReport?>((ref) async {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));
  final result = await _orgRepo.buildReport(periodStart: start, periodEnd: end);
  return result.fold((_) => null, (r) => r);
});

enum ReportPeriod { daily, weekly, monthly }

/// The period currently selected on the Reports & Analytics screen.
final selectedReportPeriodProvider =
    StateProvider.autoDispose<ReportPeriod>((ref) => ReportPeriod.daily);

/// Resolves [ReportPeriod] to concrete [start, end) bounds and builds the
/// matching report. A single provider (rather than three separate ones)
/// so switching period tabs on the Reports screen doesn't need three
/// parallel in-flight aggregations that immediately get discarded.
final periodReportProvider =
    FutureProvider.autoDispose<OperationsReport?>((ref) async {
  final period = ref.watch(selectedReportPeriodProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  late final DateTime start;
  final DateTime end = today.add(const Duration(days: 1));

  switch (period) {
    case ReportPeriod.daily:
      start = today;
    case ReportPeriod.weekly:
      // Monday-start week, matching the existing schedule screen's
      // weekly view convention.
      start = today.subtract(Duration(days: today.weekday - 1));
    case ReportPeriod.monthly:
      start = DateTime(today.year, today.month, 1);
  }

  final result = await _orgRepo.buildReport(periodStart: start, periodEnd: end);
  return result.fold((_) => null, (r) => r);
});
