import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/exercise.dart';
import '../models/exercise_tracking_type.dart';
import '../models/muscle_group.dart';
import '../providers/exercise_provider.dart';
import '../providers/repository_providers.dart';
import '../providers/workout_provider.dart';
import '../repositories/exercise_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/selection_sheet.dart';
import '../widgets/glass_app_bar.dart';

class AddExerciseScreen extends ConsumerStatefulWidget {
  final int? workoutId;
  final String? date;
  const AddExerciseScreen({super.key, this.workoutId, this.date})
    : assert(workoutId != null || date != null);

  @override
  ConsumerState<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends ConsumerState<AddExerciseScreen> {
  MuscleGroup? _selectedMuscleGroup;
  Exercise? _selectedExercise;

  void _refreshExerciseData(int muscleGroupId) {
    ref.invalidate(exercisesByMuscleGroupProvider(muscleGroupId));
    ref.invalidate(allExercisesProvider);
    ref.invalidate(libraryExercisesProvider);
    ref.invalidate(customExercisesProvider);
  }

  Future<void> _addExerciseToWorkout(Exercise exercise) async {
    final repo = ref.read(workoutRepositoryProvider);
    final workoutId =
        widget.workoutId ?? (await repo.getOrCreateWorkout(widget.date!)).id!;
    await repo.addExerciseToWorkout(workoutId, exercise.id!);
    ref.invalidate(workoutExercisesProvider(workoutId));
    ref.invalidate(allWorkoutsProvider);
    if (widget.date != null) {
      ref.invalidate(workoutByDateProvider(widget.date!));
    }
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);
    final topContentInset =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Add Exercise')),
      body: AppBackdrop(
        child: muscleGroupsAsync.when(
          data: (muscleGroups) =>
              _buildForm(context, muscleGroups, topContentInset),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
      bottomNavigationBar: Container(
        color: AppTheme.background,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton(
            onPressed: _selectedExercise == null
                ? null
                : () async => _addExerciseToWorkout(_selectedExercise!),
            child: const Text('Add to Workout'),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<MuscleGroup> muscleGroups,
    double topContentInset,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, topContentInset, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add an exercise to this workout',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a muscle group, then pick an exercise or add your own custom movement.',
                style: TextStyle(color: AppTheme.textMuted, height: 1.45),
              ),
              const SizedBox(height: 24),
              const Text(
                '1. Select Muscle Group',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              SelectionField(
                label: _selectedMuscleGroup?.name ?? 'Choose muscle group',
                onTap: () async {
                  final picked = await showSelectionSheet<MuscleGroup>(
                    context: context,
                    title: 'Select Muscle Group',
                    items: muscleGroups,
                    labelBuilder: (muscleGroup) => muscleGroup.name,
                    isSelected: (muscleGroup) =>
                        muscleGroup.id == _selectedMuscleGroup?.id,
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedMuscleGroup = picked;
                      _selectedExercise = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              if (_selectedMuscleGroup != null) ...[
                const Text(
                  '2. Select Exercise',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                _buildExercisePicker(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await _showCreateCustomExerciseSheet(
                        context,
                        _selectedMuscleGroup!,
                      );
                    },
                    icon: const Icon(
                      Icons.add_circle,
                      color: AppTheme.secondary,
                    ),
                    label: const Text('Add Custom Exercise'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExercisePicker() {
    final exercisesAsync = ref.watch(
      exercisesByMuscleGroupProvider(_selectedMuscleGroup!.id!),
    );

    return exercisesAsync.when(
      data: (exercises) {
        if (exercises.isEmpty) {
          return const Text(
            'No exercises found for this muscle group yet. Add a custom one to continue.',
          );
        }
        return SelectionField(
          label: _selectedExercise?.name ?? 'Choose exercise',
          onTap: () async {
            final picked = await showSelectionSheet<Exercise>(
              context: context,
              title: 'Select Exercise',
              items: exercises,
              labelBuilder: (exercise) => exercise.name,
              isSelected: (exercise) => exercise.id == _selectedExercise?.id,
            );
            if (picked != null) {
              setState(() {
                _selectedExercise = picked;
              });
            }
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Text('Error: $e'),
    );
  }

  Future<void> _showCreateCustomExerciseSheet(
    BuildContext context,
    MuscleGroup muscleGroup,
  ) async {
    Exercise? createdExercise;

    createdExercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String name = '';
        bool isSaving = false;
        String? errorText;
        ExerciseTrackingType trackingType =
            muscleGroup.name.toLowerCase() == 'cardio'
            ? ExerciseTrackingType.duration
            : ExerciseTrackingType.weightReps;
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(color: AppTheme.outline),
              ),
              child: StatefulBuilder(
                builder: (sheetContext, setSheetState) {
                  Future<void> saveExercise() async {
                    var didClose = false;
                    final trimmedName = name.trim();
                    if (trimmedName.isEmpty || isSaving) {
                      return;
                    }

                    setSheetState(() {
                      isSaving = true;
                      errorText = null;
                    });

                    final repo = ref.read(exerciseRepositoryProvider);
                    try {
                      final exercise = await repo.addExercise(
                        Exercise(
                          name: trimmedName,
                          muscleGroupId: muscleGroup.id!,
                          isCustom: true,
                          trackingType: trackingType,
                        ),
                      );
                      _refreshExerciseData(muscleGroup.id!);
                      if (sheetContext.mounted) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        didClose = true;
                        Navigator.of(sheetContext).pop(exercise);
                      }
                    } on DuplicateExerciseException catch (error) {
                      setSheetState(() {
                        isSaving = false;
                        errorText = error.message;
                      });
                    } finally {
                      if (sheetContext.mounted && !didClose) {
                        setSheetState(() {
                          isSaving = false;
                        });
                      }
                    }
                  }

                  final canSave = name.trim().isNotEmpty && !isSaving;

                  return SingleChildScrollView(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Create Custom Exercise',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This will be added under ${muscleGroup.name} and attached to the current workout right away.',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Logging Style',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ChoiceChip(
                            avatar: Icon(
                              Icons.fitness_center_rounded,
                              size: 18,
                              color:
                                  trackingType ==
                                      ExerciseTrackingType.weightReps
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                            label: Text(
                              ExerciseTrackingType.weightReps.displayLabel,
                            ),
                            showCheckmark: false,
                            selected:
                                trackingType == ExerciseTrackingType.weightReps,
                            selectedColor: AppTheme.primary,
                            backgroundColor: AppTheme.surfaceElevated
                                .withValues(alpha: 0.92),
                            side: BorderSide(
                              color:
                                  trackingType ==
                                      ExerciseTrackingType.weightReps
                                  ? AppTheme.primary
                                  : AppTheme.outline,
                            ),
                            labelStyle: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  trackingType ==
                                      ExerciseTrackingType.weightReps
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            onSelected: isSaving
                                ? null
                                : (_) {
                                    setSheetState(() {
                                      trackingType =
                                          ExerciseTrackingType.weightReps;
                                    });
                                  },
                          ),
                          ChoiceChip(
                            avatar: Icon(
                              Icons.repeat_rounded,
                              size: 18,
                              color: trackingType == ExerciseTrackingType.reps
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                            label: Text(ExerciseTrackingType.reps.displayLabel),
                            showCheckmark: false,
                            selected: trackingType == ExerciseTrackingType.reps,
                            selectedColor: AppTheme.primary,
                            backgroundColor: AppTheme.surfaceElevated
                                .withValues(alpha: 0.92),
                            side: BorderSide(
                              color: trackingType == ExerciseTrackingType.reps
                                  ? AppTheme.primary
                                  : AppTheme.outline,
                            ),
                            labelStyle: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  trackingType == ExerciseTrackingType.reps
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            onSelected: isSaving
                                ? null
                                : (_) {
                                    setSheetState(() {
                                      trackingType = ExerciseTrackingType.reps;
                                    });
                                  },
                          ),
                          ChoiceChip(
                            avatar: Icon(
                              Icons.timer_rounded,
                              size: 18,
                              color:
                                  trackingType == ExerciseTrackingType.duration
                                  ? Colors.white
                                  : Colors.white70,
                            ),
                            label: Text(
                              ExerciseTrackingType.duration.displayLabel,
                            ),
                            showCheckmark: false,
                            selected:
                                trackingType == ExerciseTrackingType.duration,
                            selectedColor: AppTheme.primary,
                            backgroundColor: AppTheme.surfaceElevated
                                .withValues(alpha: 0.92),
                            side: BorderSide(
                              color:
                                  trackingType == ExerciseTrackingType.duration
                                  ? AppTheme.primary
                                  : AppTheme.outline,
                            ),
                            labelStyle: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  trackingType == ExerciseTrackingType.duration
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            onSelected: isSaving
                                ? null
                                : (_) {
                                    setSheetState(() {
                                      trackingType =
                                          ExerciseTrackingType.duration;
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onChanged: (value) {
                          name = value;
                          setSheetState(() {});
                        },
                        onFieldSubmitted: (_) async => saveExercise(),
                        decoration: InputDecoration(
                          labelText: 'Exercise Name',
                          errorText: errorText,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      Navigator.of(sheetContext).pop();
                                    },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: canSave ? saveExercise : null,
                              child: Text(
                                isSaving ? 'Saving...' : 'Save & Add',
                              ),
                            ),
                          ),
                        ],
                      ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || createdExercise == null) {
      return;
    }

    await _addExerciseToWorkout(createdExercise);
  }
}
