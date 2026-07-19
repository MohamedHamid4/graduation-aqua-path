import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../shared/services/location_service.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../water_delivery/domain/repositories/water_delivery_repository.dart';

class DriverDeliveryConfirmState {
  const DriverDeliveryConfirmState({
    this.isSubmitting = false,
    this.error,
    this.success = false,
  });

  final bool isSubmitting;
  final String? error;
  final bool success;

  DriverDeliveryConfirmState copyWith({
    bool? isSubmitting,
    String? error,
    bool? success,
    bool clearError = false,
  }) {
    return DriverDeliveryConfirmState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      success: success ?? this.success,
    );
  }
}

/// Driver confirms a completed delivery: enters the amount, and the
/// driver's current GPS position and the active truck/route are attached
/// automatically — this is the "driver as source of truth" write path
/// that replaced resident self-reporting.
class DriverDeliveryConfirmNotifier
    extends AutoDisposeNotifier<DriverDeliveryConfirmState> {
  @override
  DriverDeliveryConfirmState build() => const DriverDeliveryConfirmState();

  Future<void> confirm({
    required double amountLiters,
    required String truckId,
    required String areaName,
  }) async {
    if (state.isSubmitting) return;

    if (amountLiters <= 0) {
      state = state.copyWith(error: 'يرجى إدخال كمية صحيحة', success: false);
      return;
    }

    final driverUid = GetIt.I<AuthRepository>().currentUser?.uid;
    if (driverUid == null) {
      state = state.copyWith(error: 'يجب تسجيل الدخول أولاً', success: false);
      return;
    }

    state =
        state.copyWith(isSubmitting: true, clearError: true, success: false);

    double? lat;
    double? lng;
    try {
      final pos = await GetIt.I<LocationService>().getCurrentPosition();
      lat = pos.lat;
      lng = pos.lng;
    } catch (e) {
      AppLogger.warning('Could not attach GPS to delivery confirmation: $e',
          tag: 'DriverDelivery');
    }

    final result =
        await GetIt.I<WaterDeliveryRepository>().confirmDeliveryByDriver(
      amountLiters: amountLiters,
      driverUid: driverUid,
      truckId: truckId,
      areaName: areaName,
      driverLat: lat,
      driverLng: lng,
    );

    state = result.fold(
      (failure) {
        AppLogger.warning('Delivery confirmation failed: ${failure.message}',
            tag: 'DriverDelivery');
        return DriverDeliveryConfirmState(
          isSubmitting: false,
          error: failure.message,
          success: false,
        );
      },
      (_) {
        AppLogger.info(
          'Delivery confirmed: $amountLiters L for truck $truckId in $areaName',
          tag: 'DriverDelivery',
        );
        return const DriverDeliveryConfirmState(
          isSubmitting: false,
          success: true,
        );
      },
    );
  }

  void reset() => state = const DriverDeliveryConfirmState();
}

final driverDeliveryConfirmProvider = NotifierProvider.autoDispose<
    DriverDeliveryConfirmNotifier, DriverDeliveryConfirmState>(
  DriverDeliveryConfirmNotifier.new,
);
