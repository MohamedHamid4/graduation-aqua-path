import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/parking_spot.dart';

class ParkingSpotDto {
  final String id;
  final double latitude;
  final double longitude;
  final int stopCount;
  final bool isVerified;
  final DateTime lastStoppedAt;
  final String areaName;
  final List<String> driverUids;
  final ParkingApprovalStatus approvalStatus;

  const ParkingSpotDto({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.stopCount,
    required this.isVerified,
    required this.lastStoppedAt,
    this.areaName = '',
    this.driverUids = const [],
    this.approvalStatus = ParkingApprovalStatus.pending,
  });

  factory ParkingSpotDto.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ParkingSpotDto(
      id: doc.id,
      latitude: (d['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (d['longitude'] as num?)?.toDouble() ?? 0.0,
      stopCount: (d['stopCount'] as num?)?.toInt() ?? 0,
      isVerified: d['isVerified'] as bool? ?? false,
      lastStoppedAt: d['lastStoppedAt'] != null
          ? (d['lastStoppedAt'] as Timestamp).toDate()
          : DateTime.now(),
      areaName: d['areaName'] as String? ?? '',
      driverUids: (d['driverUids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      approvalStatus:
          ParkingApprovalStatus.fromString(d['approvalStatus'] as String?),
    );
  }

  ParkingSpot toDomain() => ParkingSpot(
        id: id,
        latitude: latitude,
        longitude: longitude,
        stopCount: stopCount,
        isVerified: isVerified,
        lastStoppedAt: lastStoppedAt,
        areaName: areaName,
        driverUids: driverUids,
        approvalStatus: approvalStatus,
      );
}
