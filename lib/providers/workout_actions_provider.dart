import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'repository_providers.dart';
import 'workout_provider.dart';

class WorkoutActions {
  final Ref ref;
  WorkoutActions(this.ref);

  /// Copies a single exercise to today's workout.
  /// Does not create sets; relies on the UI to show the initial empty set row.
  Future<void> copyExerciseToToday(int exerciseId) async {
    final repo = ref.read(workoutRepositoryProvider);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final workout = await repo.getOrCreateWorkout(today);
    
    final existingExercises = await repo.getExercisesForWorkout(workout.id!);
    final isAlreadyPresent = existingExercises.any((e) => e.exerciseId == exerciseId);
    
    if (!isAlreadyPresent) {
      await repo.addExerciseToWorkout(workout.id!, exerciseId);
      
      // Invalidate providers to ensure the UI updates
      ref.invalidate(workoutByDateProvider(today));
      ref.invalidate(workoutExercisesProvider(workout.id!));
      ref.invalidate(allWorkoutsProvider);
    }
  }

  /// Copies a list of unique exercise IDs to today's workout.
  Future<void> copySessionToToday(List<int> exerciseIds) async {
    final repo = ref.read(workoutRepositoryProvider);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final workout = await repo.getOrCreateWorkout(today);
    final existingExercises = await repo.getExercisesForWorkout(workout.id!);
    final existingIds = existingExercises.map((e) => e.exerciseId).toSet();
    
    bool addedAny = false;
    for (final id in exerciseIds) {
      if (!existingIds.contains(id)) {
        await repo.addExerciseToWorkout(workout.id!, id);
        addedAny = true;
      }
    }
    
    if (addedAny) {
      ref.invalidate(workoutByDateProvider(today));
      ref.invalidate(workoutExercisesProvider(workout.id!));
      ref.invalidate(allWorkoutsProvider);
    }
  }
}

final workoutActionsProvider = Provider((ref) => WorkoutActions(ref));
