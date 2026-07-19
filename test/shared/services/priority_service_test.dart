import 'package:flutter_test/flutter_test.dart';
import 'package:aquapath/shared/services/priority_service.dart';

void main() {
  late PriorityService service;

  setUp(() {
    service = PriorityService();
  });

  group('PriorityService', () {
    test('returns critical for high score', () {
      final score = service.calculatePriority(
        householdCount: 10,
        vulnerabilityScore: 0.8,
        daysSinceServed: 5,
      );
      expect(service.getPriorityLevel(score), PriorityLevel.critical);
    });

    test('returns low for minimal inputs', () {
      final score = service.calculatePriority(
        householdCount: 1,
        vulnerabilityScore: 0.0,
        daysSinceServed: 0,
      );
      expect(service.getPriorityLevel(score), PriorityLevel.low);
    });

    test('calculates score correctly', () {
      final score = service.calculatePriority(
        householdCount: 5,
        vulnerabilityScore: 0.5,
        daysSinceServed: 3,
      );
      // (5*0.4) + (0.5*30) + (3*0.3) = 2 + 15 + 0.9 = 17.9 -> 18
      expect(score, 18);
    });
  });
}
