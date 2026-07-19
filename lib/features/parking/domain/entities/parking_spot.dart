import 'package:equatable/equatable.dart';

/// A geographic cluster where a truck has been observed stopped.
///
/// Becomes "verified" — and visible to residents on the map — once the
/// same location (within [kParkingRadiusMeters]) has recorded at least
/// [kParkingVerificationThreshold] separate stops. See
/// [ParkingSpotRepository.registerStop] for the detection logic.
///
/// [isVerified] is the *automatic* signal (stop-count threshold reached).
/// [approvalStatus] is the *organization's* manual override on top of
/// that — a spot only actually appears on the resident/organization map
/// when it is both verified AND approved. This split lets an
/// organization operator disable a false-positive cluster (e.g. a red
/// light a truck happens to idle at) without it silently reappearing the
/// next time the auto-detector re-counts stops there.
class ParkingSpot extends Equatable {
  final String id;
  final double latitude;
  final double longitude;
  final int stopCount;
  final bool isVerified;
  final DateTime lastStoppedAt;
  final String areaName;
  final List<String> driverUids;
  final ParkingApprovalStatus approvalStatus;

  const ParkingSpot({
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

  bool get isVisibleOnMap =>
      isVerified && approvalStatus == ParkingApprovalStatus.approved;

  @override
  List<Object?> get props => [
        id,
        latitude,
        longitude,
        stopCount,
        isVerified,
        lastStoppedAt,
        areaName,
        driverUids,
        approvalStatus,
      ];
}

enum ParkingApprovalStatus {
  pending,
  approved,
  disabled;

  static ParkingApprovalStatus fromString(String? raw) {
    switch (raw) {
      case 'approved':
        return ParkingApprovalStatus.approved;
      case 'disabled':
        return ParkingApprovalStatus.disabled;
      default:
        return ParkingApprovalStatus.pending;
    }
  }
}

/// A truck standing still within this radius of a previously-seen stop is
/// considered the "same" parking location.
const double kParkingRadiusMeters = 50.0;

/// Number of distinct stops at (approximately) the same location before
/// it's promoted to a verified, resident-visible parking spot.
const int kParkingVerificationThreshold = 3;
