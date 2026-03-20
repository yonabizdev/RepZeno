import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/workout_repository.dart';

final exerciseRepositoryProvider = Provider((ref) => ExerciseRepository());
final workoutRepositoryProvider = Provider((ref) => WorkoutRepository());
