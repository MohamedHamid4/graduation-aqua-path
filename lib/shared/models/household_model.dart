import 'package:equatable/equatable.dart';

class HouseholdModel extends Equatable {
  final String id;
  final String familyName;
  final String areaName;
  final int householdSize;
  final bool hasElderly;
  final bool hasSick;
  final bool hasChildren;
  final int daysSinceLastDelivery;
  final int priorityScore;
  final DateTime registeredAt;

  const HouseholdModel({
    required this.id,
    required this.familyName,
    required this.areaName,
    required this.householdSize,
    this.hasElderly = false,
    this.hasSick = false,
    this.hasChildren = false,
    this.daysSinceLastDelivery = 0,
    this.priorityScore = 0,
    required this.registeredAt,
  });

  double get vulnerabilityScore {
    double score = 0;

    if (hasElderly) score += 0.33;
    if (hasSick) score += 0.34;
    if (hasChildren) score += 0.33;

    return score;
  }

  HouseholdModel copyWith({
    String? familyName,
    String? areaName,
    int? householdSize,
    bool? hasElderly,
    bool? hasSick,
    bool? hasChildren,
    int? daysSinceLastDelivery,
    int? priorityScore,
  }) {
    return HouseholdModel(
      id: id,
      familyName: familyName ?? this.familyName,
      areaName: areaName ?? this.areaName,
      householdSize: householdSize ?? this.householdSize,
      hasElderly: hasElderly ?? this.hasElderly,
      hasSick: hasSick ?? this.hasSick,
      hasChildren: hasChildren ?? this.hasChildren,
      daysSinceLastDelivery:
          daysSinceLastDelivery ?? this.daysSinceLastDelivery,
      priorityScore: priorityScore ?? this.priorityScore,
      registeredAt: registeredAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'familyName': familyName,
      'areaName': areaName,
      'householdSize': householdSize,
      'hasElderly': hasElderly,
      'hasSick': hasSick,
      'hasChildren': hasChildren,
      'daysSinceLastDelivery': daysSinceLastDelivery,
      'priorityScore': priorityScore,
      'registeredAt': registeredAt.toIso8601String(),
    };
  }

  factory HouseholdModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return HouseholdModel(
      id: id,
      familyName: data['familyName'] ?? '',
      areaName: data['areaName'] ?? '',
      householdSize: (data['householdSize'] as num?)?.toInt() ?? 1,
      hasElderly: data['hasElderly'] ?? false,
      hasSick: data['hasSick'] ?? false,
      hasChildren: data['hasChildren'] ?? false,
      daysSinceLastDelivery:
          (data['daysSinceLastDelivery'] as num?)?.toInt() ?? 0,
      priorityScore: (data['priorityScore'] as num?)?.toInt() ?? 0,
      registeredAt: data['registeredAt'] != null
          ? DateTime.tryParse(data['registeredAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        familyName,
        areaName,
        householdSize,
        hasElderly,
        hasSick,
        hasChildren,
        daysSinceLastDelivery,
        priorityScore,
      ];
}
