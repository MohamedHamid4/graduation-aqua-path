import '../../../../shared/services/priority_service.dart';

class PriorityScore {
  final String householdId;
  final int score;
  final PriorityLevel level;

  const PriorityScore({
    required this.householdId,
    required this.score,
    required this.level,
  });
}
