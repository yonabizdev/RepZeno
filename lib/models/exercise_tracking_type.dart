enum ExerciseTrackingType { weightReps, reps, duration }

extension ExerciseTrackingTypeDb on ExerciseTrackingType {
  static const String _weightRepsValue = 'weight_reps';
  static const String _repsValue = 'reps';
  static const String _durationValue = 'duration';

  String get dbValue {
    switch (this) {
      case ExerciseTrackingType.weightReps:
        return _weightRepsValue;
      case ExerciseTrackingType.reps:
        return _repsValue;
      case ExerciseTrackingType.duration:
        return _durationValue;
    }
  }

  String get displayLabel {
    switch (this) {
      case ExerciseTrackingType.weightReps:
        return 'Weights';
      case ExerciseTrackingType.reps:
        return 'Reps';
      case ExerciseTrackingType.duration:
        return 'Duration';
    }
  }

  static ExerciseTrackingType fromDb(Object? value) {
    final raw = (value ?? _weightRepsValue).toString();
    switch (raw) {
      case _durationValue:
        return ExerciseTrackingType.duration;
      case _repsValue:
        return ExerciseTrackingType.reps;
      case _weightRepsValue:
      default:
        return ExerciseTrackingType.weightReps;
    }
  }
}
