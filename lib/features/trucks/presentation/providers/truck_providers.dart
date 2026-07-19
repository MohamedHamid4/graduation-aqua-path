import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../shared/services/eta_service.dart';
import '../../../../shared/services/location_service.dart';
import '../../domain/entities/truck.dart';
import '../../domain/repositories/truck_repository.dart';

/// Live stream of all trucks — routed through [TruckRepository] rather
/// than reading Firestore directly, so the Hive offline fallback the
/// repository already implements is actually reachable from the UI. The
/// direct-Firestore version this replaced meant AT-06 (cached data while
/// offline) never actually worked from the resident's screen, even though
/// the repository/local-source code for it existed.
final trucksStreamProvider = StreamProvider<List<Truck>>((ref) {
  return GetIt.I<TruckRepository>().getTrucksStream().map(
        (either) => either.fold((failure) => throw failure, (trucks) => trucks),
      );
});

/// Count of currently active trucks.
final activeTruckCountProvider = Provider<int>((ref) {
  return ref.watch(trucksStreamProvider).when(
        data: (trucks) => trucks.where((t) => t.isActive).length,
        loading: () => 0,
        error: (_, __) => 0,
      );
});

/// ETA service singleton.
final etaServiceProvider = Provider<EtaService>((ref) {
  return GetIt.I<EtaService>();
});

/// Location service singleton.
final locationServiceProvider = Provider<LocationService>((ref) {
  return GetIt.I<LocationService>();
});

/// Resolves the user's current device position once, falling back to
/// the Gaza-centre coordinates if permission is denied or unavailable.
final userLocationProvider =
    FutureProvider<({double lat, double lng})>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.getCurrentPosition();
});
