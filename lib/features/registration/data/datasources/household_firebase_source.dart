import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/models/household_model.dart';

class HouseholdFirebaseSource {
  final FirebaseFirestore _firestore;

  HouseholdFirebaseSource(this._firestore);

  CollectionReference get _householdsRef => _firestore.collection('households');

  /// Writes `households/{uid}` with a merge — the first submission creates
  /// the document and stamps `createdAt`; every later submission (editing
  /// the same household) updates that single document instead of adding a
  /// new one, and only touches `updatedAt`.
  Future<void> saveHousehold(String uid, HouseholdModel household) async {
    final docRef = _householdsRef.doc(uid);
    final existing = await docRef.get();

    final payload = <String, dynamic>{
      ...household.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!existing.exists) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await docRef.set(payload, SetOptions(merge: true));
  }

  Future<HouseholdModel?> getHousehold(String uid) async {
    final doc = await _householdsRef.doc(uid).get();
    if (!doc.exists) return null;
    return HouseholdModel.fromMap(uid, doc.data()! as Map<String, dynamic>);
  }

  /// Live view of `households/{uid}` — used wherever the UI needs to
  /// reflect the resident's own registered area/priority without a manual
  /// refresh (e.g. right after editing the household, or if the
  /// organization recalculates `priorityScore`).
  Stream<HouseholdModel?> watchHousehold(String uid) {
    return _householdsRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return HouseholdModel.fromMap(uid, doc.data()! as Map<String, dynamic>);
    });
  }
}
