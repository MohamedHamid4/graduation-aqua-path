import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/security/secure_storage_service.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../trucks/domain/entities/truck.dart';
import '../../../trucks/presentation/providers/truck_providers.dart';
import '../../domain/entities/water_delivery.dart';
import '../../domain/repositories/water_delivery_repository.dart';

/// Provider for the user's saved area from registration. Deliveries are
/// now addressed by area (driver-confirmed, not resident-self-reported),
/// so this is also what the delivery history/total streams key off.
final userAreaProvider = FutureProvider.autoDispose<String?>((ref) async {
  final savedArea = await GetIt.I<SecureStorageService>().savedArea;
  return savedArea?.trim();
});

/// Real-time stream of deliveries recorded for the resident's area.
final areaWaterDeliveriesProvider =
    StreamProvider.autoDispose<List<WaterDelivery>>((ref) {
  final areaAsync = ref.watch(userAreaProvider);
  final area = areaAsync.valueOrNull;

  if (area == null || area.isEmpty) {
    return Stream.value(const []);
  }

  return GetIt.I<WaterDeliveryRepository>().getAreaDeliveriesStream(area).map(
        (either) => either.fold(
          (failure) {
            debugPrint('WATER DELIVERY HISTORY ERROR: ${failure.message}');
            throw Exception(failure.message);
          },
          (deliveries) => deliveries,
        ),
      );
});

/// Real-time stream of the total water delivered to the resident's area.
final areaWaterTotalProvider = StreamProvider.autoDispose<double>((ref) {
  final areaAsync = ref.watch(userAreaProvider);
  final area = areaAsync.valueOrNull;

  if (area == null || area.isEmpty) {
    return Stream.value(0);
  }

  return GetIt.I<WaterDeliveryRepository>().getAreaTotalStream(area).map(
        (either) => either.fold(
          (failure) {
            debugPrint('WATER DELIVERY TOTAL ERROR: ${failure.message}');
            throw Exception(failure.message);
          },
          (total) => total,
        ),
      );
});

/// Finds the first active truck serving the user's registered area.
final activeTruckForUserProvider = Provider.autoDispose<Truck?>((ref) {
  final trucksAsync = ref.watch(trucksStreamProvider);
  final userAreaAsync = ref.watch(userAreaProvider);

  return trucksAsync.maybeWhen(
    data: (trucks) {
      final rawArea = userAreaAsync.valueOrNull;
      final area = rawArea?.trim();

      if (area == null || area.isEmpty) {
        return null;
      }

      for (final truck in trucks) {
        final routeName = truck.routeName.trim();
        final servedAreas =
            truck.servedAreas.map((item) => item.trim()).toList();

        final servesArea = routeName == area || servedAreas.contains(area);

        if (truck.isActive && servesArea) {
          return truck;
        }
      }

      return null;
    },
    orElse: () => null,
  );
});

/// Resident-side action: acknowledge receipt of an already-recorded
/// delivery. Never changes the amount — the driver's figure is final.
class DeliveryAcknowledgeNotifier extends AutoDisposeNotifier<Set<String>> {
  @override
  Set<String> build() => {};

  Future<void> acknowledge(String deliveryId) async {
    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    if (uid == null) return;

    state = {...state, deliveryId};
    final result = await GetIt.I<WaterDeliveryRepository>().acknowledgeDelivery(
      deliveryId: deliveryId,
      residentUid: uid,
    );
    result.fold(
      (failure) {
        debugPrint('ACKNOWLEDGE DELIVERY ERROR: ${failure.message}');
        state = {...state}..remove(deliveryId);
      },
      (_) {},
    );
  }
}

final deliveryAcknowledgeProvider =
    NotifierProvider.autoDispose<DeliveryAcknowledgeNotifier, Set<String>>(
  DeliveryAcknowledgeNotifier.new,
);
