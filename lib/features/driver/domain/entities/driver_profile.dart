import 'package:equatable/equatable.dart';

/// A registered water-truck driver.
///
/// Stored at `drivers/{uid}` in Firestore, keyed by the same Firebase Auth
/// UID used for sign-in — there is no separate driver auth system, only a
/// separate profile collection that marks an authenticated user as a
/// driver (backed, since the custom-claims migration, by the `role`
/// claim on the same account — see `core/auth/user_role.dart`).
class DriverProfile extends Equatable {
  final String uid;
  final String firstName;
  final String lastName;
  final String phone;
  final String truckPlateNumber;
  final double truckCapacity;
  final String licenseNumber;
  final String assignedArea;
  final String? profilePictureUrl;
  final String status; // 'active' | 'inactive'
  final DateTime registeredAt;

  const DriverProfile({
    required this.uid,
    this.firstName = '',
    this.lastName = '',
    required this.phone,
    required this.truckPlateNumber,
    required this.truckCapacity,
    required this.licenseNumber,
    this.assignedArea = '',
    this.profilePictureUrl,
    this.status = 'active',
    required this.registeredAt,
    @Deprecated('Use firstName/lastName. Kept only to parse legacy '
        'pre-migration documents that only ever wrote a single fullName '
        'field.')
    String? fullName,
  }) : _legacyFullName = fullName;

  final String? _legacyFullName;

  bool get isActive => status == 'active';

  /// Display name that works for both new (`firstName`/`lastName`) and
  /// legacy (single `fullName`) driver documents.
  String get fullName {
    final combined = '$firstName $lastName'.trim();
    if (combined.isNotEmpty) return combined;
    return _legacyFullName ?? '';
  }

  Map<String, dynamic> toMap() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'truckPlateNumber': truckPlateNumber,
        'truckCapacity': truckCapacity,
        'licenseNumber': licenseNumber,
        'assignedArea': assignedArea,
        if (profilePictureUrl != null) 'profilePictureUrl': profilePictureUrl,
        'status': status,
        'registeredAt': registeredAt.toIso8601String(),
      };

  factory DriverProfile.fromMap(String uid, Map<String, dynamic> data) {
    return DriverProfile(
      uid: uid,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      // ignore: deprecated_member_use_from_same_package
      fullName: data['fullName'] as String?,
      phone: data['phone'] as String? ?? '',
      truckPlateNumber: data['truckPlateNumber'] as String? ?? '',
      truckCapacity: (data['truckCapacity'] as num?)?.toDouble() ?? 10000.0,
      licenseNumber: data['licenseNumber'] as String? ?? '',
      assignedArea: data['assignedArea'] as String? ?? '',
      profilePictureUrl: data['profilePictureUrl'] as String?,
      status: data['status'] as String? ?? 'active',
      registeredAt: data['registeredAt'] != null
          ? DateTime.tryParse(data['registeredAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  DriverProfile copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? truckPlateNumber,
    double? truckCapacity,
    String? licenseNumber,
    String? assignedArea,
    String? profilePictureUrl,
    String? status,
  }) {
    return DriverProfile(
      uid: uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      truckPlateNumber: truckPlateNumber ?? this.truckPlateNumber,
      truckCapacity: truckCapacity ?? this.truckCapacity,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      assignedArea: assignedArea ?? this.assignedArea,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      status: status ?? this.status,
      registeredAt: registeredAt,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        firstName,
        lastName,
        phone,
        truckPlateNumber,
        truckCapacity,
        licenseNumber,
        assignedArea,
        profilePictureUrl,
        status,
      ];
}
