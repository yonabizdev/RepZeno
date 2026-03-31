import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise.dart';
import '../models/exercise_tracking_type.dart';
import '../models/muscle_group.dart';
import '../providers/exercise_provider.dart';
import '../providers/repository_providers.dart';
import '../providers/workout_provider.dart';
import '../repositories/exercise_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/selection_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/app_backdrop.dart';

enum _ExerciseLibraryFilter { all, builtIn, custom }

class _MuscleFilterOption {
  final int? id;
  final String label;

  const _MuscleFilterOption({required this.id, required this.label});
}

class ExerciseManagementScreen extends ConsumerStatefulWidget {
  const ExerciseManagementScreen({super.key});

  @override
  ConsumerState<ExerciseManagementScreen> createState() =>
      _ExerciseManagementScreenState();
}

class _ExerciseManagementScreenState
    extends ConsumerState<ExerciseManagementScreen> {
  _ExerciseLibraryFilter _filter = _ExerciseLibraryFilter.all;
  String _searchQuery = '';
  int? _selectedMuscleGroupId;

  @override
  Widget build(BuildContext context) {
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);
    final libraryExercisesAsync = ref.watch(libraryExercisesProvider);
    final topContentInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Manage Exercises')),
      body: AppBackdrop(
        child: muscleGroupsAsync.when(
          data: (muscleGroups) => ListView(
            padding: EdgeInsets.fromLTRB(16, topContentInset, 16, 24),
            children: [
              ElevatedButton.icon(
                onPressed: () =>
                    _openExerciseEditor(muscleGroups: muscleGroups),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add New Exercise'),
              ),
              const SizedBox(height: 18),
              _buildLibraryCard(
                libraryExercisesAsync: libraryExercisesAsync,
                muscleGroups: muscleGroups,
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildLibraryCard({
    required AsyncValue<List<Exercise>> libraryExercisesAsync,
    required List<MuscleGroup> muscleGroups,
  }) {
    final muscleFilterOptions = [
      const _MuscleFilterOption(id: null, label: 'All muscles'),
      ...muscleGroups.map(
        (muscleGroup) =>
            _MuscleFilterOption(id: muscleGroup.id, label: muscleGroup.name),
      ),
    ];
    final selectedMuscleLabel = muscleFilterOptions
        .firstWhere(
          (option) => option.id == _selectedMuscleGroupId,
          orElse: () =>
              const _MuscleFilterOption(id: null, label: 'All muscles'),
        )
        .label;
    final muscleGroupNames = {
      for (final muscleGroup in muscleGroups) muscleGroup.id!: muscleGroup.name,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exercise Library',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Edit or remove built-in and custom exercises from one place. Built-in items are labeled so the list stays easy to understand.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search exercises by name',
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == _ExerciseLibraryFilter.all,
                  onTap: () => setState(() {
                    _filter = _ExerciseLibraryFilter.all;
                  }),
                ),
                _FilterChip(
                  label: 'Built-in',
                  selected: _filter == _ExerciseLibraryFilter.builtIn,
                  onTap: () => setState(() {
                    _filter = _ExerciseLibraryFilter.builtIn;
                  }),
                ),
                _FilterChip(
                  label: 'Custom',
                  selected: _filter == _ExerciseLibraryFilter.custom,
                  onTap: () => setState(() {
                    _filter = _ExerciseLibraryFilter.custom;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SelectionField(
              label: selectedMuscleLabel,
              onTap: () async {
                final picked = await showSelectionSheet<_MuscleFilterOption>(
                  context: context,
                  title: 'Select Muscle Group',
                  items: muscleFilterOptions,
                  labelBuilder: (option) => option.label,
                  isSelected: (option) => option.id == _selectedMuscleGroupId,
                );
                if (picked != null) {
                  setState(() {
                    _selectedMuscleGroupId = picked.id;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            libraryExercisesAsync.when(
              data: (exercises) {
                final filtered = exercises
                    .where(
                      (exercise) => _matchesFilter(
                        exercise,
                        muscleGroupNames[exercise.muscleGroupId],
                      ),
                    )
                    .toList();

                if (filtered.isEmpty) {
                  return Text(
                    _emptyStateMessage(),
                    style: const TextStyle(color: Colors.white70),
                  );
                }

                final grouped = <String, List<Exercise>>{};

                for (final exercise in filtered) {
                  final muscleGroupName =
                      muscleGroupNames[exercise.muscleGroupId] ??
                      'Unknown muscle group';
                  grouped.putIfAbsent(muscleGroupName, () => []).add(exercise);
                }

                final sortedGroups = grouped.keys.toList()..sort();

                return Column(
                  children: [
                    for (final muscleGroupName in sortedGroups)
                      _MuscleGroupSection(
                        title: muscleGroupName,
                        exercises: grouped[muscleGroupName]!,
                        onEdit: (exercise) => _openExerciseEditor(
                          muscleGroups: muscleGroups,
                          exercise: exercise,
                        ),
                        onDelete: _confirmDelete,
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesFilter(Exercise exercise, String? muscleGroupName) {
    final matchesLibraryFilter = switch (_filter) {
      _ExerciseLibraryFilter.all => true,
      _ExerciseLibraryFilter.builtIn => !exercise.isCustom,
      _ExerciseLibraryFilter.custom => exercise.isCustom,
    };

    final matchesSearch =
        _searchQuery.isEmpty ||
        exercise.name.toLowerCase().contains(_searchQuery) ||
        (muscleGroupName?.toLowerCase().contains(_searchQuery) ?? false);

    final matchesMuscleGroup =
        _selectedMuscleGroupId == null ||
        exercise.muscleGroupId == _selectedMuscleGroupId;

    return matchesLibraryFilter && matchesSearch && matchesMuscleGroup;
  }

  String _emptyStateMessage() {
    if (_searchQuery.isNotEmpty) {
      return 'No exercises match "$_searchQuery". Try a different name or clear a filter.';
    }

    if (_selectedMuscleGroupId != null) {
      return 'No ${_filterLabel(_filter).toLowerCase()} exercises match this muscle group.';
    }

    switch (_filter) {
      case _ExerciseLibraryFilter.all:
        return 'No exercises available yet.';
      case _ExerciseLibraryFilter.builtIn:
        return 'No built-in exercises match this filter.';
      case _ExerciseLibraryFilter.custom:
        return 'No custom exercises match this filter.';
    }
  }

  String _filterLabel(_ExerciseLibraryFilter filter) {
    switch (filter) {
      case _ExerciseLibraryFilter.all:
        return 'All';
      case _ExerciseLibraryFilter.builtIn:
        return 'Built-in';
      case _ExerciseLibraryFilter.custom:
        return 'Custom';
    }
  }

  Future<void> _confirmDelete(Exercise exercise) async {
    final repo = ref.read(exerciseRepositoryProvider);
    final usageCount = await repo.getExerciseUsageCount(exercise.id!);
    if (usageCount > 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${exercise.name}" has workout history and can’t be deleted.',
          ),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete exercise?'),
            content: Text(
              'Delete "${exercise.name}" from your exercise library? It will be removed from future exercise pickers.',
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: const Color(0xFFFF8D8D),
                        side: const BorderSide(
                          color: Color(0x66FF7A7A),
                          width: 1.5,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }

    try {
      await repo.deleteExercise(exercise.id!);
    } on ExerciseInUseException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    _refreshExerciseData();
  }

  Future<void> _openExerciseEditor({
    required List<MuscleGroup> muscleGroups,
    Exercise? exercise,
  }) async {
    final repo = ref.read(exerciseRepositoryProvider);
    final usageCount = exercise == null
        ? 0
        : await repo.getExerciseUsageCount(exercise.id!);
    final isLocked = usageCount > 0;

    if (!mounted) {
      return;
    }

    String name = exercise?.name ?? '';
    MuscleGroup? selectedMuscleGroup;
    ExerciseTrackingType trackingType =
        exercise?.trackingType ?? ExerciseTrackingType.weightReps;
    if (exercise != null) {
      selectedMuscleGroup = muscleGroups.firstWhere(
        (muscleGroup) => muscleGroup.id == exercise.muscleGroupId,
        orElse: () => MuscleGroup(id: exercise.muscleGroupId, name: 'Unknown'),
      );
    }

    bool isSaving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final warningColor = Theme.of(dialogContext).colorScheme.error;
            Future<void> saveExercise() async {
              var didClose = false;
              final trimmedName = name.trim();
              if (trimmedName.isEmpty || selectedMuscleGroup == null) {
                return;
              }

              setDialogState(() {
                isSaving = true;
                errorText = null;
              });

              final repo = ref.read(exerciseRepositoryProvider);
              final toSave = Exercise(
                id: exercise?.id,
                name: trimmedName,
                muscleGroupId: selectedMuscleGroup!.id!,
                isCustom: exercise?.isCustom ?? true,
                trackingType: trackingType,
              );

              try {
                if (exercise == null) {
                  await repo.addExercise(toSave);
                } else {
                  await repo.updateExercise(toSave);
                }
                _refreshExerciseData();
                if (dialogContext.mounted) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  didClose = true;
                  Navigator.of(dialogContext).pop();
                }
              } on DuplicateExerciseException catch (error) {
                setDialogState(() {
                  errorText = error.message;
                });
              } on ExerciseInUseException catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.message)));
                }
              } finally {
                if (dialogContext.mounted && !didClose) {
                  setDialogState(() {
                    isSaving = false;
                  });
                }
              }
            }

            return Dialog(
              backgroundColor: AppTheme.surface,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AppTheme.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exercise == null
                                  ? 'Add Exercise'
                                  : 'Edit Exercise',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (exercise != null)
                            _ExerciseOriginBadge(isCustom: exercise.isCustom),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        exercise == null
                            ? 'Create a custom exercise and keep your library tidy.'
                            : isLocked
                            ? 'Update the exercise name. This affects where it appears in pickers.'
                            : 'Update the name or muscle group. This affects where it appears in pickers.',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                      if (exercise != null && isLocked) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: warningColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: warningColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: warningColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This exercise has workout history. Muscle group and logging style are locked.',
                                  style: TextStyle(
                                    color: warningColor.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w400,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      TextFormField(
                        initialValue: name,
                        autofocus: exercise == null,
                        textInputAction: TextInputAction.next,
                        onChanged: (value) {
                          name = value;
                          if (errorText != null) {
                            errorText = null;
                          }
                          setDialogState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: 'Exercise Name',
                          errorText: errorText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SelectionField(
                        label:
                            selectedMuscleGroup?.name ?? 'Select muscle group',
                        onTap: () async {
                          if (exercise != null && isLocked) {
                            return;
                          }
                          FocusManager.instance.primaryFocus?.unfocus();
                          final picked = await showSelectionSheet<MuscleGroup>(
                            context: dialogContext,
                            title: 'Select Muscle Group',
                            items: muscleGroups,
                            labelBuilder: (muscleGroup) => muscleGroup.name,
                            isSelected: (muscleGroup) =>
                                muscleGroup.id == selectedMuscleGroup?.id,
                          );
                          if (picked != null && dialogContext.mounted) {
                            setDialogState(() {
                              selectedMuscleGroup = picked;
                              errorText = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
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
                            onSelected: isSaving || isLocked
                                ? null
                                : (_) {
                                    setDialogState(() {
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
                            onSelected: isSaving || isLocked
                                ? null
                                : (_) {
                                    setDialogState(() {
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
                            onSelected: isSaving || isLocked
                                ? null
                                : (_) {
                                    setDialogState(() {
                                      trackingType =
                                          ExerciseTrackingType.duration;
                                    });
                                  },
                          ),
                        ],
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
                                      Navigator.of(dialogContext).pop();
                                    },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  (!isSaving &&
                                      name.trim().isNotEmpty &&
                                      selectedMuscleGroup != null)
                                  ? saveExercise
                                  : null,
                              child: Text(exercise == null ? 'Save' : 'Update'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _refreshExerciseData() {
    ref.invalidate(allExercisesProvider);
    ref.invalidate(libraryExercisesProvider);
    ref.invalidate(customExercisesProvider);
    ref.invalidate(exercisesByMuscleGroupProvider);
    ref.invalidate(muscleHistoryProvider);
  }
}

class _MuscleGroupSection extends StatelessWidget {
  final String title;
  final List<Exercise> exercises;
  final ValueChanged<Exercise> onEdit;
  final ValueChanged<Exercise> onDelete;

  const _MuscleGroupSection({
    required this.title,
    required this.exercises,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sortedExercises = [...exercises]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...sortedExercises.map(
            (exercise) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ExerciseOriginBadge(isCustom: exercise.isCustom),
                            _ExerciseTrackingBadge(
                              trackingType: exercise.trackingType,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () => onEdit(exercise),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => onDelete(exercise),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFFF8D8D),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseOriginBadge extends StatelessWidget {
  final bool isCustom;

  const _ExerciseOriginBadge({required this.isCustom});

  @override
  Widget build(BuildContext context) {
    final label = isCustom ? 'Custom' : 'Built-in';
    final background = isCustom
        ? AppTheme.secondary.withValues(alpha: 0.14)
        : AppTheme.primary.withValues(alpha: 0.14);
    final foreground = isCustom ? AppTheme.secondary : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ExerciseTrackingBadge extends StatelessWidget {
  final ExerciseTrackingType trackingType;

  const _ExerciseTrackingBadge({required this.trackingType});

  @override
  Widget build(BuildContext context) {
    final isDuration = trackingType == ExerciseTrackingType.duration;
    final isRepsOnly = trackingType == ExerciseTrackingType.reps;
    final label = trackingType.displayLabel;
    final icon = isDuration
        ? Icons.timer_rounded
        : isRepsOnly
        ? Icons.repeat_rounded
        : Icons.fitness_center_rounded;
    final foreground = isDuration
        ? AppTheme.tertiary
        : isRepsOnly
        ? AppTheme.secondary
        : AppTheme.primary;
    final background = foreground.withValues(alpha: 0.14);
    final borderColor = foreground.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surfaceElevated.withValues(alpha: 0.92),
      side: BorderSide(color: selected ? AppTheme.primary : AppTheme.outline),
      labelStyle: TextStyle(
        color: Colors.white,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) => onTap(),
    );
  }
}
