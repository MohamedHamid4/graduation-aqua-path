import 'package:equatable/equatable.dart';

class Truck extends Equatable {
  final String id;
  final String driverName;
  final double latitude;
  final double longitude;
  final double averageSpeed;
  final String status;
  final double capacity;
  final double currentLoad;
  final double distributedAmount;
  final int deliveryCount;
  final String? activeRouteId;
  final List<String> servedAreas;
  final DateTime lastUpdated;
  final DateTime? lastDeliveryAt;
  final String routeName;

  /// When the current trip started (set on `startTrip`, cleared on
  /// `endTrip`). Used to compute "working hours" on the organization's
  /// live-monitoring driver detail — there was previously no way to
  /// derive this at all, since only `lastUpdated` (a rolling per-tick
  /// timestamp, not a trip start) was tracked.
  final DateTime? tripStartedAt;

  const Truck({
    required this.id,
    required this.driverName,
    required this.latitude,
    required this.longitude,
    this.averageSpeed = 25.0,
    this.status = 'active',
    this.capacity = 10000.0,
    this.currentLoad = 10000.0,
    this.distributedAmount = 0.0,
    this.deliveryCount = 0,
    this.activeRouteId,
    this.servedAreas = const [],
    required this.lastUpdated,
    this.lastDeliveryAt,
    this.routeName = '',
    this.tripStartedAt,
  });

  double get loadPercentage =>
      capacity > 0 ? (currentLoad / capacity).clamp(0.0, 1.0) : 0.0;

  double get distributionPercentage =>
      capacity > 0 ? (distributedAmount / capacity).clamp(0.0, 1.0) : 0.0;

  bool get isActive => status == 'active';

  /// Elapsed time since the current trip started, or null if no trip is
  /// active. This is what "working hours" on the organization map
  /// actually displays.
  Duration? get workingDuration =>
      tripStartedAt == null ? null : DateTime.now().difference(tripStartedAt!);

  Truck copyWith({
    String? id,
    String? driverName,
    double? latitude,
    double? longitude,
    double? averageSpeed,
    String? status,
    double? capacity,
    double? currentLoad,
    double? distributedAmount,
    int? deliveryCount,
    String? activeRouteId,
    List<String>? servedAreas,
    DateTime? lastUpdated,
    DateTime? lastDeliveryAt,
    String? routeName,
    DateTime? tripStartedAt,
  }) {
    return Truck(
      id: id ?? this.id,
      driverName: driverName ?? this.driverName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
      currentLoad: currentLoad ?? this.currentLoad,
      distributedAmount: distributedAmount ?? this.distributedAmount,
      deliveryCount: deliveryCount ?? this.deliveryCount,
      activeRouteId: activeRouteId ?? this.activeRouteId,
      servedAreas: servedAreas ?? this.servedAreas,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastDeliveryAt: lastDeliveryAt ?? this.lastDeliveryAt,
      routeName: routeName ?? this.routeName,
      tripStartedAt: tripStartedAt ?? this.tripStartedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        driverName,
        latitude,
        longitude,
        averageSpeed,
        status,
        capacity,
        currentLoad,
        distributedAmount,
        deliveryCount,
        activeRouteId,
        servedAreas,
        lastUpdated,
        lastDeliveryAt,
        routeName,
        tripStartedAt,
      ];
}
