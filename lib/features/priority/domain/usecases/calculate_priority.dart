import '../../../../shared/services/priority_service.dart';
import '../entities/priority_score.dart';

class CalculatePriority {
  final PriorityService service;

  const CalculatePriority(this.service);

  PriorityScore call({
    required String householdId,
    required int householdCount,
    required double vulnerabilityScore,
    required int daysSinceServed,
  }) {
    final score = service.calculatePriority(
      householdCount: householdCount,
      vulnerabilityScore: vulnerabilityScore,
      daysSinceServed: daysSinceServed,
    );
    return PriorityScore(
      householdId: householdId,
      score: score,
      level: service.getPriorityLevel(score),
    );
  }
}
