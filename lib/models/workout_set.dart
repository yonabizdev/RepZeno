class WorkoutSet {
  final int? id;
  final int workoutExerciseId;
  final double? weight;
  final int? reps;
  final int? durationSeconds;
  final String createdAt;

  WorkoutSet({
    this.id,
    required this.workoutExerciseId,
    this.weight,
    this.reps,
    this.durationSeconds,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'workoutExerciseId': workoutExerciseId,
      'weight': weight,
      'reps': reps,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt,
    };
  }

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    final weightValue = map['weight'];
    final repsValue = map['reps'];
    final durationValue = map['durationSeconds'];
    return WorkoutSet(
      id: map['id'],
      workoutExerciseId: map['workoutExerciseId'],
      weight: weightValue == null ? null : (weightValue as num).toDouble(),
      reps: repsValue == null ? null : (repsValue as num).toInt(),
      durationSeconds: durationValue == null
          ? null
          : (durationValue as num).toInt(),
      createdAt: map['createdAt'],
    );
  }
}
