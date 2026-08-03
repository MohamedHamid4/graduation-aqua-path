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

// Every stream below propagates a repository Left(Failure) by rethrowing
// it (either.fold's error branch) instead of silently collapsing it to an
// empty list. Swallowing the failure made a real error (permission-denied,
// a missing composite index, an actual network failure) visually
// indistinguishable from "there's genuinely nothing here yet" — the
// screen's AsyncValue.error handler is what actually gets a chance to
// show the real cause instead.

final allDriversProvider = StreamProvider<List<DriverProfile>>((ref) {
  return _orgRepo.watchAllDrivers().map(
        (either) => either.fold((failure) => throw failure, (d) => d),
      );
});

final allHouseholdsProvider = StreamProvider<List<HouseholdModel>>((ref) {
  return _orgRepo.watchAllHouseholds().map(
        (either) => either.fold((failure) => throw failure, (h) => h),
      );
});

final allAreasProvider = StreamProvider<List<ServiceArea>>((ref) {
  return _orgRepo.watchAllAreas().map(
        (either) => either.fold((failure) => throw failure, (a) => a),
      );
});

final allRoutesProvider = StreamProvider<List<DriverRoute>>((ref) {
  return _orgRepo.watchAllRoutes().map(
        (either) => either.fold((failure) => throw failure, (r) => r),
      );
});

final notificationHistoryProvider =
    StreamProvider<List<OrgNotification>>((ref) {
  return _orgRepo.watchNotificationHistory().map(
        (either) => either.fold((failure) => throw failure, (n) => n),
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
