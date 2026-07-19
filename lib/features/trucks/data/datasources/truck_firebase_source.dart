import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/truck_dto.dart';

class TruckFirebaseSource {
  final FirebaseFirestore _firestore;

  TruckFirebaseSource(this._firestore);

  CollectionReference get _ref => _firestore.collection('trucks');

  Stream<List<TruckDto>> getTrucksStream() {
    return _ref.snapshots().map(
          (snap) =>
              snap.docs.map((doc) => TruckDto.fromFirestore(doc)).toList(),
        );
  }

  Future<TruckDto?> getTruckById(String id) async {
    final doc = await _ref.doc(id).get();
    if (!doc.exists) return null;
    return TruckDto.fromFirestore(doc);
  }

  Future<void> updateTruckLocation(
    String truckId,
    double lat,
    double lng,
  ) async {
    await _ref.doc(truckId).update({
      'latitude': lat,
      'longitude': lng,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addTruck(TruckDto truck) async {
    await _ref.doc(truck.id).set(truck.toFirestore());
  }

  /// Creates (or resumes) the truck document for a driver starting a trip.
  /// Now initializes aggregation fields for water delivery.
  Future<void> startTrip({
    required String truckId,
    required String driverName,
    required String routeName,
    required double lat,
    required double lng,
    required double capacity,
    String? activeRouteId,
  }) async {
    await _ref.doc(truckId).set({
      'driverName': driverName,
      'routeName': routeName,
      'latitude': lat,
      'longitude': lng,
      'status': 'active',
      'capacity': capacity,
      'currentLoad': capacity, // Reset remaining water to full
      'distributedAmount': 0.0,
      'deliveryCount': 0,
      'activeRouteId': activeRouteId,
      'lastDeliveryAt': null,
      'lastUpdated': FieldValue.serverTimestamp(),
      'tripStartedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> endTrip(String truckId) async {
    await _ref.doc(truckId).set({
      'status': 'idle',
      'activeRouteId': null,
      'tripStartedAt': null,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Driver-initiated pause — distinct from [endTrip]: the active route
  /// stays assigned, only the operational status changes, so resuming
  /// doesn't require re-selecting the route.
  Future<void> pauseTrip(String truckId) async {
    await _ref.doc(truckId).update({
      'status': 'paused',
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resumeTrip(String truckId) async {
    await _ref.doc(truckId).update({
      'status': 'active',
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Driver confirms a delivered quantity. Atomically decrements the
  /// truck's remaining load and increments the distributed total/delivery
  /// count in one write, so the resident-facing "remaining load" figure
  /// can never drift out of sync with delivery confirmations.
  Future<void> recordDelivery({
    required String truckId,
    required double liters,
  }) async {
    await _ref.doc(truckId).update({
      'currentLoad': FieldValue.increment(-liters),
      'distributedAmount': FieldValue.increment(liters),
      'deliveryCount': FieldValue.increment(1),
      'lastDeliveryAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}
