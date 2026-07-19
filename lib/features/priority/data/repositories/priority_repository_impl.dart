import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/priority_score.dart';

/// Persists computed priority scores to the `areas` Firestore collection.
class PriorityRepositoryImpl {
  final FirebaseFirestore firestore;

  const PriorityRepositoryImpl(this.firestore);

  Future<void> savePriorityScore(PriorityScore score) async {
    await firestore.collection('areas').doc(score.householdId).set(
      {
        'priorityScore': score.score,
        'priorityLevel': score.level.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
