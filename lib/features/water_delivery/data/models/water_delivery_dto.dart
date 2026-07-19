import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/water_delivery.dart';

class WaterDeliveryDto {
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

  const WaterDeliveryDto({
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

  factory WaterDeliveryDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WaterDeliveryDto(
      deliveryId: doc.id,
      driverUid: data['driverUid'] as String? ?? '',
      truckId: data['truckId'] as String? ?? '',
      tripId: data['tripId'] as String? ?? '',
      amountLiters: (data['amountLiters'] as num?)?.toDouble() ?? 0.0,
      areaName: data['areaName'] as String? ?? '',
      driverLat: (data['driverLat'] as num?)?.toDouble(),
      driverLng: (data['driverLng'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acknowledgedByUids: (data['acknowledgedByUids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'driverUid': driverUid,
      'truckId': truckId,
      'tripId': tripId,
      'amountLiters': amountLiters,
      'areaName': areaName,
      if (driverLat != null) 'driverLat': driverLat,
      if (driverLng != null) 'driverLng': driverLng,
      'createdAt': FieldValue.serverTimestamp(),
      'acknowledgedByUids': acknowledgedByUids,
    };
  }

  WaterDelivery toDomain() {
    return WaterDelivery(
      deliveryId: deliveryId,
      driverUid: driverUid,
      truckId: truckId,
      tripId: tripId,
      amountLiters: amountLiters,
      areaName: areaName,
      driverLat: driverLat,
      driverLng: driverLng,
      createdAt: createdAt,
      acknowledgedByUids: acknowledgedByUids,
    );
  }
}
