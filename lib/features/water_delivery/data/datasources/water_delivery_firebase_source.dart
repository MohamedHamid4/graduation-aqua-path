import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/water_delivery_dto.dart';

class WaterDeliveryFirebaseSource {
  final FirebaseFirestore _firestore;

  WaterDeliveryFirebaseSource(this._firestore);

  CollectionReference get _deliveriesRef =>
      _firestore.collection('water_deliveries');
  CollectionReference get _trucksRef => _firestore.collection('trucks');

  Stream<List<WaterDeliveryDto>> getAreaDeliveriesStream(String areaName) {
    return _deliveriesRef
        .where('areaName', isEqualTo: areaName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => WaterDeliveryDto.fromFirestore(doc))
            .toList());
  }

  /// Atomic transaction: driver confirms delivery, truck aggregates
  /// (remaining load / distributed total / delivery count) update in the
  /// same write so they can never drift out of sync with the recorded
  /// delivery documents.
  Future<void> submitDriverDeliveryTransaction(WaterDeliveryDto dto) async {
    final truckDocRef = _trucksRef.doc(dto.truckId);

    return _firestore.runTransaction((transaction) async {
      final truckSnapshot = await transaction.get(truckDocRef);

      if (!truckSnapshot.exists) {
        throw Exception('الشاحنة المطلوبة غير موجودة');
      }

      final truckData = truckSnapshot.data() as Map<String, dynamic>;
      final status = truckData['status'] as String? ?? 'idle';
      final activeRouteId = truckData['activeRouteId'] as String?;
      final currentLoad = (truckData['currentLoad'] as num?)?.toDouble() ?? 0.0;
      final distributedAmount =
          (truckData['distributedAmount'] as num?)?.toDouble() ?? 0.0;
      final deliveryCount = (truckData['deliveryCount'] as num?)?.toInt() ?? 0;

      if (status != 'active') {
        throw Exception('لا توجد رحلة توزيع نشطة حالياً');
      }
      if (activeRouteId == null || activeRouteId.isEmpty) {
        throw Exception('لا توجد رحلة توزيع نشطة حالياً');
      }
      if (dto.amountLiters <= 0) {
        throw Exception('يرجى إدخال كمية صحيحة');
      }
      if (currentLoad <= 0 || dto.amountLiters > currentLoad) {
        throw Exception('لا توجد كمية مياه كافية في الشاحنة');
      }

      final deliveryDocRef = _deliveriesRef.doc();
      transaction.set(deliveryDocRef, {
        ...dto.toFirestore(),
        'tripId': activeRouteId,
      });

      transaction.update(truckDocRef, {
        'currentLoad': currentLoad - dto.amountLiters,
        'distributedAmount': distributedAmount + dto.amountLiters,
        'deliveryCount': deliveryCount + 1,
        'lastDeliveryAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> acknowledgeDelivery(
      String deliveryId, String residentUid) async {
    await _deliveriesRef.doc(deliveryId).update({
      'acknowledgedByUids': FieldValue.arrayUnion([residentUid]),
    });
  }
}
