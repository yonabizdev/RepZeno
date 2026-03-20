class WorkoutExercise {
  final int? id;
  final int workoutId;
  final int exerciseId;

  WorkoutExercise({this.id, required this.workoutId, required this.exerciseId});

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'workoutId': workoutId,
      'exerciseId': exerciseId,
    };
  }

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      id: map['id'],
      workoutId: map['workoutId'],
      exerciseId: map['exerciseId'],
    );
  }
}
