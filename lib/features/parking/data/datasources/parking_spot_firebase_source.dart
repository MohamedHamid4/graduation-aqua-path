import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/geo_utils.dart';
import '../../domain/entities/parking_spot.dart';
import '../models/parking_spot_dto.dart';

class ParkingSpotFirebaseSource {
  final FirebaseFirestore _firestore;

  ParkingSpotFirebaseSource(this._firestore);

  CollectionReference get _ref => _firestore.collection('parking_spots');

  /// Map-ready spots: auto-verified AND organization-approved. Used by
  /// both the resident map and (merged with pending/disabled) the
  /// organization dashboard.
  Stream<List<ParkingSpotDto>> watchVerifiedSpots() {
    return _ref
        .where('isVerified', isEqualTo: true)
        .where('approvalStatus', isEqualTo: 'approved')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ParkingSpotDto.fromFirestore(doc)).toList());
  }

  /// Every spot regardless of verification/approval state — the
  /// organization dashboard's parking-management list.
  Stream<List<ParkingSpotDto>> watchAllSpots() {
    return _ref.snapshots().map(
          (snap) => snap.docs
              .map((doc) => ParkingSpotDto.fromFirestore(doc))
              .toList(),
        );
  }

  /// Finds the closest existing spot within [kParkingRadiusMeters] of
  /// (lat, lng) and increments its stop count, promoting it to verified
  /// once more than [kParkingVerificationThreshold] stops have been
  /// recorded — or creates a brand new candidate spot if nothing nearby
  /// exists yet. Newly-created and newly-verified spots start life as
  /// `approvalStatus: pending`; an organization operator must approve a
  /// spot before it is shown on any map (see [approveSpot]).
  ///
  /// The nearest-match lookup fetches the whole collection and measures
  /// distance client-side rather than a native radius query — Firestore
  /// has no built-in geo-radius query, and a city-scale deployment (at
  /// most a few dozen distinct parking clusters) makes this a reasonable
  /// trade-off over adding a geohashing dependency. The increment itself
  /// runs inside a transaction so two near-simultaneous reports of the
  /// same stop can't silently lose one of the counts.
  Future<void> registerStop({
    required double latitude,
    required double longitude,
    required String driverUid,
    required String areaName,
  }) async {
    final snapshot = await _ref.get();

    String? nearestId;
    double nearestDistance = double.infinity;

    for (final doc in snapshot.docs) {
      final dto = ParkingSpotDto.fromFirestore(doc);
      final distance = GeoUtils.distanceMeters(
        latitude,
        longitude,
        dto.latitude,
        dto.longitude,
      );
      if (distance <= kParkingRadiusMeters && distance < nearestDistance) {
        nearestDistance = distance;
        nearestId = doc.id;
      }
    }

    if (nearestId == null) {
      await _ref.add({
        'latitude': latitude,
        'longitude': longitude,
        'stopCount': 1,
        'isVerified': false,
        'lastStoppedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'areaName': areaName,
        'driverUids': [driverUid],
        'approvalStatus': 'pending',
      });
      return;
    }

    final docRef = _ref.doc(nearestId);
    await _firestore.runTransaction((transaction) async {
      final fresh = await transaction.get(docRef);
      if (!fresh.exists) return;

      final data = fresh.data() as Map<String, dynamic>;
      final oldCount = (data['stopCount'] as num?)?.toInt() ?? 0;
      final oldLat = (data['latitude'] as num?)?.toDouble() ?? latitude;
      final oldLng = (data['longitude'] as num?)?.toDouble() ?? longitude;
      final newCount = oldCount + 1;
      final existingDrivers = (data['driverUids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{};
      existingDrivers.add(driverUid);

      // Nudge the centroid toward the new observation so the marker
      // converges on the true center of the cluster over time, instead
      // of staying pinned to wherever the very first stop happened to be.
      final weightedLat = oldLat + (latitude - oldLat) / newCount;
      final weightedLng = oldLng + (longitude - oldLng) / newCount;

      transaction.update(docRef, {
        'stopCount': newCount,
        'latitude': weightedLat,
        'longitude': weightedLng,
        // "more than three stops" per spec => verified starting the 4th.
        'isVerified': newCount > kParkingVerificationThreshold,
        'lastStoppedAt': FieldValue.serverTimestamp(),
        'areaName': areaName,
        'driverUids': existingDrivers.toList(),
      });
    });
  }

  // ── Organization management ─────────────────────────────────────────
  Future<void> setApprovalStatus(String spotId, String status) async {
    await _ref.doc(spotId).update({'approvalStatus': status});
  }

  Future<void> updateSpot(String spotId, Map<String, dynamic> patch) async {
    await _ref.doc(spotId).update(patch);
  }

  Future<void> deleteSpot(String spotId) async {
    await _ref.doc(spotId).delete();
  }
}
