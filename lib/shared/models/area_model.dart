import 'package:equatable/equatable.dart';

class AreaModel extends Equatable {
  final String id;
  final String name;
  final int priorityScore;
  final int householdCount;
  final DateTime? lastServed;

  const AreaModel({
    required this.id,
    required this.name,
    this.priorityScore = 0,
    this.householdCount = 0,
    this.lastServed,
  });

  factory AreaModel.fromMap(String id, Map<String, dynamic> data) {
    return AreaModel(
      id: id,
      name: data['name'] as String? ?? '',
      priorityScore: (data['priorityScore'] as num?)?.toInt() ?? 0,
      householdCount: (data['householdCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'priorityScore': priorityScore,
        'householdCount': householdCount,
      };

  @override
  List<Object?> get props => [id, name, priorityScore, householdCount];
}
