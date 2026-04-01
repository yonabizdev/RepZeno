import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/muscle_group.dart';
import '../models/exercise.dart';
import 'repository_providers.dart';

final muscleGroupsProvider = FutureProvider<List<MuscleGroup>>((ref) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  return repo.getMuscleGroups();
});

final exercisesByMuscleGroupProvider =
    FutureProvider.family<List<Exercise>, int>((ref, muscleGroupId) async {
      final repo = ref.watch(exerciseRepositoryProvider);
      return repo.getExercisesByMuscleGroup(muscleGroupId);
    });

final allExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  return repo.getAllExercises();
});

final libraryExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  return repo.getLibraryExercises();
});

final customExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final repo = ref.watch(exerciseRepositoryProvider);
  return repo.getCustomExercises();
});

class LastSelectedMuscleGroupNotifier extends Notifier<MuscleGroup?> {
  @override
  MuscleGroup? build() => null;

  void update(MuscleGroup? value) => state = value;
}

final lastSelectedMuscleGroupProvider =
    NotifierProvider<LastSelectedMuscleGroupNotifier, MuscleGroup?>(
      LastSelectedMuscleGroupNotifier.new,
    );
