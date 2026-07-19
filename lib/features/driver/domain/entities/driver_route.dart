import 'package:equatable/equatable.dart';

/// A single scheduled delivery assignment for a driver — the unit shown on
/// the driver's work-schedule screen and used to draw the route map.
///
/// `startLat/startLng` is the trip's departure point (e.g. the water
/// depot); `endLat/endLng` is the destination area's centroid — the same
/// kind of coordinate the resident side already uses for ETA calculation.
class DriverRoute extends Equatable {
  final String id;
  final String driverUid;
  final String areaName;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final DateTime scheduledTime;
  final String timeSlot;
  final String status; // 'pending' | 'in_progress' | 'completed'
  final double expectedLiters;

  const DriverRoute({
    required this.id,
    required this.driverUid,
    required this.areaName,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.scheduledTime,
    required this.timeSlot,
    this.status = 'pending',
    this.expectedLiters = 8000,
  });

  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  DriverRoute copyWith({String? status}) {
    return DriverRoute(
      id: id,
      driverUid: driverUid,
      areaName: areaName,
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      scheduledTime: scheduledTime,
      timeSlot: timeSlot,
      status: status ?? this.status,
      expectedLiters: expectedLiters,
    );
  }

  Map<String, dynamic> toMap() => {
        'driverUid': driverUid,
        'areaName': areaName,
        'startLat': startLat,
        'startLng': startLng,
        'endLat': endLat,
        'endLng': endLng,
        'scheduledTime': scheduledTime.toIso8601String(),
        'timeSlot': timeSlot,
        'status': status,
        'expectedLiters': expectedLiters,
      };

  factory DriverRoute.fromMap(String id, Map<String, dynamic> data) {
    return DriverRoute(
      id: id,
      driverUid: data['driverUid'] as String? ?? '',
      areaName: data['areaName'] as String? ?? '',
      startLat: (data['startLat'] as num?)?.toDouble() ?? 31.5018,
      startLng: (data['startLng'] as num?)?.toDouble() ?? 34.4668,
      endLat: (data['endLat'] as num?)?.toDouble() ?? 31.5018,
      endLng: (data['endLng'] as num?)?.toDouble() ?? 34.4668,
      scheduledTime: data['scheduledTime'] != null
          ? DateTime.tryParse(data['scheduledTime'] as String) ?? DateTime.now()
          : DateTime.now(),
      timeSlot: data['timeSlot'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      expectedLiters: (data['expectedLiters'] as num?)?.toDouble() ?? 8000,
    );
  }

  @override
  List<Object?> get props => [
        id,
        driverUid,
        areaName,
        startLat,
        startLng,
        endLat,
        endLng,
        scheduledTime,
        timeSlot,
        status,
        expectedLiters,
      ];
}
