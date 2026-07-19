import 'package:flutter_test/flutter_test.dart';

import 'package:aquapath/shared/models/household_model.dart';

void main() {
  group('HouseholdModel', () {
    test('vulnerabilityScore sums the three weighted flags', () {
      final household = HouseholdModel(
        id: 'uid-1',
        familyName: 'عائلة تجريبية',
        areaName: 'الشجاعية',
        householdSize: 5,
        hasElderly: true,
        hasSick: true,
        hasChildren: true,
        registeredAt: DateTime(2026, 1, 1),
      );

      expect(household.vulnerabilityScore, closeTo(1.0, 0.001));
    });

    test('vulnerabilityScore is 0 with no flags set', () {
      final household = HouseholdModel(
        id: 'uid-1',
        familyName: 'عائلة تجريبية',
        areaName: 'الشجاعية',
        householdSize: 5,
        registeredAt: DateTime(2026, 1, 1),
      );

      expect(household.vulnerabilityScore, 0.0);
    });

    test('toMap/fromMap round-trips all fields (id is kept out-of-band)', () {
      final original = HouseholdModel(
        id: 'uid-1',
        familyName: 'عائلة تجريبية',
        areaName: 'خان يونس',
        householdSize: 6,
        hasElderly: true,
        hasSick: false,
        hasChildren: true,
        daysSinceLastDelivery: 4,
        priorityScore: 22,
        registeredAt: DateTime(2026, 3, 10),
      );

      final restored = HouseholdModel.fromMap('uid-1', original.toMap());

      expect(restored.id, original.id);
      expect(restored.familyName, original.familyName);
      expect(restored.areaName, original.areaName);
      expect(restored.householdSize, original.householdSize);
      expect(restored.hasElderly, original.hasElderly);
      expect(restored.hasSick, original.hasSick);
      expect(restored.hasChildren, original.hasChildren);
      expect(restored.daysSinceLastDelivery, original.daysSinceLastDelivery);
      expect(restored.priorityScore, original.priorityScore);
    });

    test('fromMap fills in safe defaults for missing fields', () {
      final household = HouseholdModel.fromMap('uid-2', const {});

      expect(household.id, 'uid-2');
      expect(household.familyName, '');
      expect(household.areaName, '');
      expect(household.householdSize, 1);
      expect(household.hasElderly, false);
      expect(household.priorityScore, 0);
    });

    test('copyWith preserves the id and registeredAt (identity fields)', () {
      final original = HouseholdModel(
        id: 'uid-3',
        familyName: 'عائلة تجريبية',
        areaName: 'رفح',
        householdSize: 3,
        registeredAt: DateTime(2026, 1, 1),
      );

      final updated = original.copyWith(householdSize: 8, hasSick: true);

      expect(updated.id, 'uid-3');
      expect(updated.registeredAt, DateTime(2026, 1, 1));
      expect(updated.householdSize, 8);
      expect(updated.hasSick, true);
      expect(updated.familyName, 'عائلة تجريبية');
      expect(updated.areaName, 'رفح');
    });
  });
}
