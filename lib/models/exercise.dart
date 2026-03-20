import 'exercise_tracking_type.dart';

class Exercise {
  final int? id;
  final String name;
  final int muscleGroupId;
  final bool isCustom;
  final ExerciseTrackingType trackingType;

  Exercise({
    this.id,
    required this.name,
    required this.muscleGroupId,
    this.isCustom = false,
    this.trackingType = ExerciseTrackingType.weightReps,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'muscleGroupId': muscleGroupId,
      'isCustom': isCustom ? 1 : 0,
      'trackingType': trackingType.dbValue,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      name: map['name'],
      muscleGroupId: map['muscleGroupId'],
      isCustom: (map['isCustom'] ?? 0) == 1,
      trackingType: ExerciseTrackingTypeDb.fromDb(map['trackingType']),
    );
  }

  Exercise copyWith({
    int? id,
    String? name,
    int? muscleGroupId,
    bool? isCustom,
    ExerciseTrackingType? trackingType,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroupId: muscleGroupId ?? this.muscleGroupId,
      isCustom: isCustom ?? this.isCustom,
      trackingType: trackingType ?? this.trackingType,
    );
  }
}
