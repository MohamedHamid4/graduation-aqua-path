import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../shared/models/household_model.dart';
import '../../../driver/domain/entities/driver_profile.dart';
import '../../../driver/domain/entities/driver_route.dart';
import '../../domain/entities/organization_profile.dart';
import '../../domain/entities/service_area.dart';

class OrganizationFirebaseSource {
  final FirebaseFirestore _firestore;
  // TODO(backend): requires the 'setDriverStatus' Cloud Function deployed in
  // functions/src/index.ts — it calls Admin SDK auth.updateUser({disabled}).
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  OrganizationFirebaseSource(this._firestore);

  CollectionReference get _driversRef => _firestore.collection('drivers');
  CollectionReference get _householdsRef => _firestore.collection('households');
  CollectionReference get _areasRef => _firestore.collection('areas');
  CollectionReference get _routesRef => _firestore.collection('driver_routes');
  CollectionReference get _orgsRef => _firestore.collection('organizations');
  CollectionReference get _trucksRef => _firestore.collection('trucks');
  CollectionReference get _notificationsRef =>
      _firestore.collection('notifications');

  Future<void> sendNotification(Map<String, dynamic> data) async {
    await _notificationsRef.add(data);
  }

  Stream<List<Map<String, dynamic>>> watchNotificationHistory() {
    return _notificationsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList(),
        );
  }

  Future<List<Map<String, dynamic>>> fetchAllTrucksOnce() async {
    final snap = await _trucksRef.get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllDriversOnce() async {
    final snap = await _driversRef.get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchRoutesInRange(
    DateTime start,
    DateTime end,
  ) async {
    final snap = await _routesRef
        .where('scheduledTime', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('scheduledTime', isLessThanOrEqualTo: end.toIso8601String())
        .get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
  }

  /// Delivery records actually confirmed within [start, end) — the
  /// correct basis for period-scoped reports. `trucks.distributedAmount`
  /// (used by an earlier version of [OrganizationRepositoryImpl.buildReport])
  /// is a lifetime running total, not scoped to any period, so a
  /// "weekly" or "monthly" report built from it would have shown the
  /// exact same number as the daily one — this is what that bug looked
  /// like from the data side.
  ///
  /// `createdAt` is a Firestore `Timestamp` (written via
  /// `FieldValue.serverTimestamp()`), unlike `driver_routes.scheduledTime`
  /// above which is a plain ISO string — the two collections don't use
  /// the same convention, so the query bounds below intentionally differ
  /// in type from [fetchRoutesInRange].
  Future<List<Map<String, dynamic>>> fetchDeliveriesInRange(
    DateTime start,
    DateTime end,
  ) async {
    final snap = await _firestore
        .collection('water_deliveries')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    return snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
  }

  Future<OrganizationProfile?> getOwnProfile(String uid) async {
    final doc = await _orgsRef.doc(uid).get();
    if (!doc.exists) return null;
    return OrganizationProfile.fromMap(uid, doc.data() as Map<String, dynamic>);
  }

  Stream<List<DriverProfile>> watchAllDrivers() {
    return _driversRef.snapshots().map(
          (snap) => snap.docs
              .map((d) =>
                  DriverProfile.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  /// Deactivating a driver must block their Firebase Auth login, not just
  /// update the Firestore display field. The callable runs server-side with
  /// Admin SDK privileges to set `disabled` on the Auth account; Firestore
  /// is only written after that succeeds so the two systems stay in sync.
  Future<void> setDriverStatus(String driverUid, String status) async {
    final disabled = status != 'active';
    await _functions.httpsCallable('setDriverStatus').call<void>({
      'uid': driverUid,
      'disabled': disabled,
    });
    await _driversRef.doc(driverUid).update({'status': status});
  }

  Future<void> assignDriverToArea(String driverUid, String areaId) async {
    await _areasRef.doc(areaId).update({
      'assignedDriverUids': FieldValue.arrayUnion([driverUid]),
    });
  }

  Future<void> updateTruckInfo(
    String driverUid, {
    required String truckPlateNumber,
    required double truckCapacity,
  }) async {
    await _driversRef.doc(driverUid).update({
      'truckPlateNumber': truckPlateNumber,
      'truckCapacity': truckCapacity,
    });
  }

  Stream<List<HouseholdModel>> watchAllHouseholds() {
    return _householdsRef.snapshots().map(
          (snap) => snap.docs
              .map((d) => HouseholdModel.fromMap(
                  d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  Stream<List<ServiceArea>> watchAllAreas() {
    return _areasRef.snapshots().map(
          (snap) => snap.docs
              .map((d) =>
                  ServiceArea.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  String newAreaId() => _areasRef.doc().id;

  Future<void> upsertArea(ServiceArea area) async {
    await _areasRef.doc(area.id).set(area.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteArea(String areaId) async {
    await _areasRef.doc(areaId).delete();
  }

  Stream<List<DriverRoute>> watchAllRoutes() {
    return _routesRef.orderBy('scheduledTime').snapshots().map(
          (snap) => snap.docs
              .map((d) =>
                  DriverRoute.fromMap(d.id, d.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  Future<void> createRoute(DriverRoute route) async {
    await _routesRef.add(route.toMap());
  }

  Future<void> deleteRoute(String routeId) async {
    await _routesRef.doc(routeId).delete();
  }
}
