import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';
import 'repository_providers.dart';

final workoutByDateProvider = FutureProvider.autoDispose
    .family<Workout?, String>((ref, date) async {
      final repo = ref.watch(workoutRepositoryProvider);
      return repo.getWorkoutByDate(date);
    });

final workoutExercisesProvider = FutureProvider.autoDispose
    .family<List<WorkoutExercise>, int>((ref, workoutId) async {
      final repo = ref.watch(workoutRepositoryProvider);
      return repo.getExercisesForWorkout(workoutId);
    });

final allWorkoutsProvider = FutureProvider<List<Workout>>((ref) async {
  final repo = ref.watch(workoutRepositoryProvider);
  return repo.getAllWorkouts();
});

final workoutSetsProvider = FutureProvider.autoDispose
    .family<List<WorkoutSet>, int>((ref, workoutExerciseId) async {
      final repo = ref.watch(workoutRepositoryProvider);
      return repo.getSetsForWorkoutExercise(workoutExerciseId);
    });

final muscleHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, muscleGroupId) async {
      final repo = ref.watch(workoutRepositoryProvider);
      return repo.getMuscleHistory(muscleGroupId);
    });
