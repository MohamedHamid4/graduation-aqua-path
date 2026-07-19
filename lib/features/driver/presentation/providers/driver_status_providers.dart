import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../trucks/domain/entities/truck.dart';
import '../../../trucks/presentation/providers/truck_providers.dart';

/// Real-time provider for the logged-in driver's truck document.
final currentDriverTruckProvider =
    Provider.autoDispose<AsyncValue<Truck?>>((ref) {
  final trucksAsync = ref.watch(trucksStreamProvider);
  final currentUid = GetIt.I<AuthRepository>().currentUser?.uid;

  return trucksAsync.whenData((trucks) {
    if (currentUid == null) return null;
    try {
      return trucks.firstWhere((t) => t.id == currentUid);
    } catch (_) {
      return null;
    }
  });
});
