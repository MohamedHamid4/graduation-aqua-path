import 'package:equatable/equatable.dart';

/// Stored at `areas/{areaId}`. Read by every role (residents need area
/// names for registration/filtering); writes are organization-only under
/// the hardened Firestore rules.
class ServiceArea extends Equatable {
  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final List<String> assignedDriverUids;

  const ServiceArea({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    this.assignedDriverUids = const [],
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'centerLat': centerLat,
        'centerLng': centerLng,
        'assignedDriverUids': assignedDriverUids,
      };

  factory ServiceArea.fromMap(String id, Map<String, dynamic> data) {
    return ServiceArea(
      id: id,
      name: data['name'] as String? ?? '',
      centerLat: (data['centerLat'] as num?)?.toDouble() ?? 31.5,
      centerLng: (data['centerLng'] as num?)?.toDouble() ?? 34.46,
      assignedDriverUids: (data['assignedDriverUids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  ServiceArea copyWith({List<String>? assignedDriverUids}) => ServiceArea(
        id: id,
        name: name,
        centerLat: centerLat,
        centerLng: centerLng,
        assignedDriverUids: assignedDriverUids ?? this.assignedDriverUids,
      );

  @override
  List<Object?> get props =>
      [id, name, centerLat, centerLng, assignedDriverUids];
}
