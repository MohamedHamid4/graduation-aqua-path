import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../shared/providers/household_provider.dart';
import '../../../driver/domain/entities/driver_route.dart';
import '../../../driver/domain/repositories/driver_repository.dart';

/// Real upcoming distribution visits for the signed-in resident's own
/// area — replaces what used to be a hardcoded illustrative calendar.
/// Sourced from the same `driver_routes` collection the organization
/// schedules and drivers already work from (see
/// [DriverRepository.watchRoutesForArea]), filtered to routes that
/// haven't been completed yet, ordered by scheduled time.
final upcomingAreaRoutesProvider =
    StreamProvider.autoDispose<List<DriverRoute>>((ref) {
  final household = ref.watch(currentHouseholdProvider).valueOrNull;
  final area = household?.areaName.trim();

  if (area == null || area.isEmpty) {
    return Stream.value(const []);
  }

  return GetIt.I<DriverRepository>().watchRoutesForArea(area).map(
        (either) => either.fold(
          (_) => const <DriverRoute>[],
          (routes) => routes.where((r) => !r.isCompleted).toList(),
        ),
      );
});

/// Resolves a driver's display name for a route card, one lookup per
/// distinct `driverUid` — cached by Riverpod's `.family` so the same
/// driver appearing on multiple upcoming routes only fetches once.
final driverNameProvider =
    FutureProvider.autoDispose.family<String, String>((ref, driverUid) async {
  final result = await GetIt.I<DriverRepository>().getDriverProfile(driverUid);
  return result.fold(
    (_) => '',
    (profile) => profile?.fullName ?? '',
  );
});
