import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../shared/providers/household_provider.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../trucks/domain/entities/truck.dart';
import '../../../trucks/presentation/providers/truck_providers.dart';
import '../../domain/entities/water_delivery.dart';
import '../../domain/repositories/water_delivery_repository.dart';

/// The resident's area, read live from `households/{uid}` — NOT from a
/// locally cached copy (SecureStorage) — because the water_deliveries
/// Firestore rule re-derives the caller's area from that same document
/// (`get(households/$(uid)).data.areaName`) to authorize the query. If the
/// client filtered by a stale cached area that no longer matches the live
/// document (edited household, org reassignment, cache never synced),
/// every document would fail that per-doc check and Firestore would reject
/// the *entire* list query with permission-denied — which surfaced to
/// residents as a bogus "check your internet connection" error. Reading
/// the same document the rule checks against makes the two impossible to
/// disagree.
final userAreaProvider = Provider.autoDispose<String?>((ref) {
  final household = ref.watch(currentHouseholdProvider).valueOrNull;
  final area = household?.areaName.trim();
  return (area == null || area.isEmpty) ? null : area;
});

/// Real-time stream of deliveries recorded for the resident's area.
final areaWaterDeliveriesProvider =
    StreamProvider.autoDispose<List<WaterDelivery>>((ref) {
  final area = ref.watch(userAreaProvider);

  if (area == null || area.isEmpty) {
    return Stream.value(const []);
  }

  return GetIt.I<WaterDeliveryRepository>().getAreaDeliveriesStream(area).map(
        (either) => either.fold(
          (failure) {
            debugPrint('WATER DELIVERY HISTORY ERROR: ${failure.message}');
            throw failure;
          },
          (deliveries) => deliveries,
        ),
      );
});

/// Real-time stream of the total water delivered to the resident's area.
final areaWaterTotalProvider = StreamProvider.autoDispose<double>((ref) {
  final area = ref.watch(userAreaProvider);

  if (area == null || area.isEmpty) {
    return Stream.value(0);
  }

  return GetIt.I<WaterDeliveryRepository>().getAreaTotalStream(area).map(
        (either) => either.fold(
          (failure) {
            debugPrint('WATER DELIVERY TOTAL ERROR: ${failure.message}');
            throw failure;
          },
          (total) => total,
        ),
      );
});

/// Finds the first active truck serving the user's registered area.
final activeTruckForUserProvider = Provider.autoDispose<Truck?>((ref) {
  final trucksAsync = ref.watch(trucksStreamProvider);
  final rawArea = ref.watch(userAreaProvider);

  return trucksAsync.maybeWhen(
    data: (trucks) {
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
