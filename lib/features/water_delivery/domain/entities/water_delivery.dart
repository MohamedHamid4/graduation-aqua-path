import 'package:equatable/equatable.dart';

/// A driver-confirmed water delivery.
///
/// Driver is the source of truth (see `driverUid`/`driverLat`/`driverLng`)
/// — residents no longer self-report quantities. A delivery is addressed
/// by `areaName`, not a specific household, because a driver serving a
/// street doesn't select an individual resident; every resident whose
/// registered area matches sees the delivery in their history and may
/// optionally [acknowledgedByUids]-acknowledge it.
class WaterDelivery extends Equatable {
  final String deliveryId;
  final String driverUid;
  final String truckId;
  final String tripId;
  final double amountLiters;
  final String areaName;
  final double? driverLat;
  final double? driverLng;
  final DateTime createdAt;
  final List<String> acknowledgedByUids;

  const WaterDelivery({
    required this.deliveryId,
    required this.driverUid,
    required this.truckId,
    required this.tripId,
    required this.amountLiters,
    required this.areaName,
    this.driverLat,
    this.driverLng,
    required this.createdAt,
    this.acknowledgedByUids = const [],
  });

  bool acknowledgedBy(String uid) => acknowledgedByUids.contains(uid);

  @override
  List<Object?> get props => [
        deliveryId,
        driverUid,
        truckId,
        tripId,
        amountLiters,
        areaName,
        driverLat,
        driverLng,
        createdAt,
        acknowledgedByUids,
      ];
}
