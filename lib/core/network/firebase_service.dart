import 'package:cloud_firestore/cloud_firestore.dart';

/// Provides typed references to all Firestore collections.
class FirebaseService {
  final FirebaseFirestore _firestore;

  const FirebaseService(this._firestore);

  CollectionReference get trucksRef => _firestore.collection('trucks');

  CollectionReference get notificationsRef =>
      _firestore.collection('notifications');

  CollectionReference get areasRef => _firestore.collection('areas');

  Future<void> updateAreaPriority(
    String areaId,
    Map<String, dynamic> data,
  ) async {
    await areasRef.doc(areaId).set(data, SetOptions(merge: true));
  }
}
