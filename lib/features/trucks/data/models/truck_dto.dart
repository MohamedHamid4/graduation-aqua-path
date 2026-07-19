import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/truck.dart';

/// Data Transfer Object for Firestore <-> Domain conversion.
class TruckDto {
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
  final DateTime? tripStartedAt;

  const TruckDto({
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

  /// Construct from a Firestore document snapshot.
  factory TruckDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TruckDto.fromMap(doc.id, data);
  }

  /// Construct from a plain map (used for local cache).
  factory TruckDto.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseOptionalDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return TruckDto(
      id: id.isNotEmpty ? id : (data['id'] as String? ?? ''),
      driverName: data['driverName'] as String? ?? 'غير معروف',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      averageSpeed: (data['averageSpeed'] as num?)?.toDouble() ?? 25.0,
      status: data['status'] as String? ?? 'active',
      capacity: (data['capacity'] as num?)?.toDouble() ?? 10000.0,
      currentLoad: (data['currentLoad'] as num?)?.toDouble() ?? 10000.0,
      distributedAmount: (data['distributedAmount'] as num?)?.toDouble() ?? 0.0,
      deliveryCount: (data['deliveryCount'] as num?)?.toInt() ?? 0,
      activeRouteId: data['activeRouteId'] as String?,
      servedAreas: List<String>.from(data['servedAreas'] as List? ?? []),
      lastUpdated: parseDate(data['lastUpdated']),
      lastDeliveryAt: parseOptionalDate(data['lastDeliveryAt']),
      routeName: data['routeName'] as String? ?? '',
      tripStartedAt: parseOptionalDate(data['tripStartedAt']),
    );
  }

  Truck toDomain() => Truck(
        id: id,
        driverName: driverName,
        latitude: latitude,
        longitude: longitude,
        averageSpeed: averageSpeed,
        status: status,
        capacity: capacity,
        currentLoad: currentLoad,
        distributedAmount: distributedAmount,
        deliveryCount: deliveryCount,
        activeRouteId: activeRouteId,
        servedAreas: servedAreas,
        lastUpdated: lastUpdated,
        lastDeliveryAt: lastDeliveryAt,
        routeName: routeName,
        tripStartedAt: tripStartedAt,
      );

  /// Map for Firestore write (uses server timestamp).
  Map<String, dynamic> toFirestore() => {
        'driverName': driverName,
        'latitude': latitude,
        'longitude': longitude,
        'averageSpeed': averageSpeed,
        'status': status,
        'capacity': capacity,
        'currentLoad': currentLoad,
        'distributedAmount': distributedAmount,
        'deliveryCount': deliveryCount,
        'activeRouteId': activeRouteId,
        'servedAreas': servedAreas,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastDeliveryAt':
            lastDeliveryAt != null ? Timestamp.fromDate(lastDeliveryAt!) : null,
        'routeName': routeName,
        'tripStartedAt':
            tripStartedAt != null ? Timestamp.fromDate(tripStartedAt!) : null,
      };

  /// Plain map for local Hive cache (ISO-8601 timestamp).
  Map<String, dynamic> toMap() => {
        'id': id,
        'driverName': driverName,
        'latitude': latitude,
        'longitude': longitude,
        'averageSpeed': averageSpeed,
        'status': status,
        'capacity': capacity,
        'currentLoad': currentLoad,
        'distributedAmount': distributedAmount,
        'deliveryCount': deliveryCount,
        'activeRouteId': activeRouteId,
        'servedAreas': servedAreas,
        'lastUpdated': lastUpdated.toIso8601String(),
        'lastDeliveryAt': lastDeliveryAt?.toIso8601String(),
        'routeName': routeName,
        'tripStartedAt': tripStartedAt?.toIso8601String(),
      };
}
