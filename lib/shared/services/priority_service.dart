/// Calculates household priority score for water distribution.
class PriorityService {
  /// Score = (householdCount × 0.4) + (vulnerability × 30) + (daysSince × 0.3)
  int calculatePriority({
    required int householdCount,
    required double vulnerabilityScore,
    required int daysSinceServed,
  }) {
    return ((householdCount * 0.4) +
            (vulnerabilityScore * 30) +
            (daysSinceServed * 0.3))
        .round();
  }

  PriorityLevel getPriorityLevel(int score) {
    if (score >= 30) return PriorityLevel.critical;
    if (score >= 20) return PriorityLevel.high;
    if (score >= 10) return PriorityLevel.medium;
    return PriorityLevel.low;
  }
}

enum PriorityLevel {
  critical('حرج', 0xFFEF4444),
  high('عالي', 0xFFF97316),
  medium('متوسط', 0xFFF59E0B),
  low('منخفض', 0xFF10B981);

  final String labelAr;
  final int colorValue;
  const PriorityLevel(this.labelAr, this.colorValue);
}
