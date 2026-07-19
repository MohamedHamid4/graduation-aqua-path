import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/driver_profile.dart';
import '../../domain/entities/driver_route.dart';

class DriverFirebaseSource {
  final FirebaseFirestore _firestore;

  DriverFirebaseSource(this._firestore);

  CollectionReference get _driversRef => _firestore.collection('drivers');
  CollectionReference get _routesRef => _firestore.collection('driver_routes');

  Future<bool> isDriver(String uid) async {
    final doc = await _driversRef.doc(uid).get();
    return doc.exists;
  }

  Future<void> registerDriverProfile(DriverProfile profile) async {
    await _driversRef.doc(profile.uid).set(profile.toMap());
  }

  Future<DriverProfile?> getDriverProfile(String uid) async {
    final doc = await _driversRef.doc(uid).get();
    if (!doc.exists) return null;
    return DriverProfile.fromMap(uid, doc.data() as Map<String, dynamic>);
  }

  Stream<List<DriverRoute>> watchRoutesForDriver(String driverUid) {
    return _routesRef
        .where('driverUid', isEqualTo: driverUid)
        .orderBy('scheduledTime')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => DriverRoute.fromMap(
                    d.id,
                    d.data() as Map<String, dynamic>,
                  ))
              .toList(),
        );
  }

  /// Live routes scheduled for a given area, regardless of which driver is
  /// assigned — this is what lets a resident's schedule screen show real
  /// upcoming distribution visits instead of a fabricated calendar.
  /// Requires the (areaName ASC, scheduledTime ASC) composite index on
  /// `driver_routes` (see firebase/firestore.indexes.json).
  Stream<List<DriverRoute>> watchRoutesForArea(String areaName) {
    return _routesRef
        .where('areaName', isEqualTo: areaName)
        .orderBy('scheduledTime')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => DriverRoute.fromMap(
                    d.id,
                    d.data() as Map<String, dynamic>,
                  ))
              .toList(),
        );
  }

  Future<void> updateRouteStatus({
    required String routeId,
    required String status,
  }) async {
    await _routesRef.doc(routeId).update({'status': status});
  }

  Future<void> updateProfilePicture(String uid, String downloadUrl) async {
    await _driversRef.doc(uid).update({'profilePictureUrl': downloadUrl});
  }
}
