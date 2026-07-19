import 'package:equatable/equatable.dart';

/// Stored at `organizations/{uid}`. Created exclusively by the
/// `createOrganizationUser` Cloud Function — there is no client-side
/// create path, matching the "no self-service organization signup"
/// requirement.
class OrganizationProfile extends Equatable {
  final String uid;
  final String orgName;
  final String contactEmail;
  final String contactPhone;
  final DateTime createdAt;

  const OrganizationProfile({
    required this.uid,
    required this.orgName,
    required this.contactEmail,
    required this.contactPhone,
    required this.createdAt,
  });

  factory OrganizationProfile.fromMap(String uid, Map<String, dynamic> data) {
    return OrganizationProfile(
      uid: uid,
      orgName: data['orgName'] as String? ?? '',
      contactEmail: data['contactEmail'] as String? ?? '',
      contactPhone: data['contactPhone'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [uid, orgName, contactEmail, contactPhone];
}
