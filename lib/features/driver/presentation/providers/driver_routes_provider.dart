import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/entities/driver_route.dart';
import '../../domain/repositories/driver_repository.dart';

/// Live stream of the signed-in driver's assigned routes, ordered by
/// scheduled time — the data source for the work-schedule screen.
final driverRoutesProvider = StreamProvider<List<DriverRoute>>((ref) {
  final uid = GetIt.I<AuthRepository>().currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  return GetIt.I<DriverRepository>().watchRoutesForDriver(uid).map(
        (either) =>
            either.fold((_) => const <DriverRoute>[], (routes) => routes),
      );
});

/// The route currently in progress, if any — used by the map screen to
/// know which assignment it's tracking.
final activeDriverRouteProvider = Provider<DriverRoute?>((ref) {
  final routes = ref.watch(driverRoutesProvider).valueOrNull ?? [];
  for (final r in routes) {
    if (r.isInProgress) return r;
  }
  return null;
});
