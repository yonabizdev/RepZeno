import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/exercise_tracking_type.dart';
import '../../models/workout_exercise.dart';
import '../../models/workout_set.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../quick_history_sheet.dart';
import 'set_row_item.dart';

class ExerciseCard extends ConsumerStatefulWidget {
  final WorkoutExercise workoutExercise;
  final String date;

  const ExerciseCard({
    super.key,
    required this.workoutExercise,
    required this.date,
  });

  @override
  ConsumerState<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<ExerciseCard> {
  @override
  Widget build(BuildContext context) {
    // Optimized stats watcher
    final setsAsync = ref.watch(workoutSetsProvider(widget.workoutExercise.id!));

    // Optimized watchers for static data using .select
    final exerciseData = ref.watch(allExercisesProvider.select((asyncValue) {
      return asyncValue.value?.where((e) => e.id == widget.workoutExercise.exerciseId).firstOrNull;
    }));

    final muscleGroupName = ref.watch(muscleGroupsProvider.select((asyncValue) {
      if (exerciseData == null) return 'Loading...';
      return asyncValue.value?.where((mg) => mg.id == exerciseData.muscleGroupId).firstOrNull?.name ?? 'Loading...';
    }));

    final exerciseName = exerciseData?.name ?? 'Loading...';
    final trackingType = exerciseData?.trackingType ?? ExerciseTrackingType.weightReps;

    final isDuration = trackingType == ExerciseTrackingType.duration;
    final isRepsOnly = trackingType == ExerciseTrackingType.reps;

    final trackingIcon = isDuration
        ? Icons.timer_rounded
        : isRepsOnly
            ? Icons.repeat_rounded
            : Icons.fitness_center_rounded;

    final trackingColor = isDuration
        ? AppTheme.tertiary
        : isRepsOnly
            ? AppTheme.secondary
            : AppTheme.primary;

    final historyAsync = ref.watch(exerciseHistoryProvider(widget.workoutExercise.exerciseId));
    final hasHistory = historyAsync.maybeWhen(
      data: (allHistory) => allHistory.any((row) {
        final rowDate = DateTime.tryParse(row['workout_date'] as String);
        final currentDate = DateTime.tryParse(widget.date);
        if (rowDate == null || currentDate == null) return false;
        return rowDate.isBefore(currentDate);
      }),
      orElse: () => false,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            muscleGroupName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(trackingIcon, size: 18, color: trackingColor),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      exerciseName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: hasHistory ? 1.0 : 0.35,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.secondary.withValues(alpha: 0.12),
                    foregroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.all(10),
                    shape: const CircleBorder(),
                    side: BorderSide(
                      color: AppTheme.secondary.withValues(alpha: 0.25),
                    ),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 22),
                  onPressed: hasHistory
                      ? () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => QuickHistorySheet(
                              exerciseId: widget.workoutExercise.exerciseId,
                              exerciseName: exerciseName,
                              muscleGroupId: exerciseData?.muscleGroupId ?? 1,
                              currentDate: widget.date,
                            ),
                          );
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x33FF6B6B),
                  foregroundColor: const Color(0xFFFF8D8D),
                  side: const BorderSide(color: Color(0x66FF7A7A)),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _handleDeleteExercise(context, exerciseName, muscleGroupName),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildTableHeader(isDuration, isRepsOnly),
          const Divider(height: 22),
          setsAsync.when(
            data: (visibleSets) {
              final isAscending = ref.watch(sortSetsAscendingProvider);
              final displayIndices = isAscending
                  ? List.generate(visibleSets.length, (i) => i)
                  : List.generate(visibleSets.length, (i) => i).reversed.toList();

              final addSetRow = isDuration
                  ? AddDurationSetRow(
                      workoutExerciseId: widget.workoutExercise.id!,
                      workoutId: widget.workoutExercise.workoutId,
                      nextSetIndex: visibleSets.length + 1,
                    )
                  : isRepsOnly
                      ? AddRepsSetRow(
                          workoutExerciseId: widget.workoutExercise.id!,
                          workoutId: widget.workoutExercise.workoutId,
                          nextSetIndex: visibleSets.length + 1,
                        )
                      : AddSetRow(
                          workoutExerciseId: widget.workoutExercise.id!,
                          workoutId: widget.workoutExercise.workoutId,
                          nextSetIndex: visibleSets.length + 1,
                        );

              return Column(
                children: [
                  if (!isAscending) addSetRow,
                  for (final i in displayIndices)
                    _buildSetRow(visibleSets[i], i + 1, isDuration, isRepsOnly),
                  if (isAscending) addSetRow,
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDuration, bool isRepsOnly) {
    if (isDuration) {
      return Row(
        children: const [
          SizedBox(width: 40, child: Text('Set', style: TextStyle(color: AppTheme.textMuted))),
          Expanded(child: Text('Duration', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted))),
          SizedBox(width: 44),
        ],
      );
    } else if (isRepsOnly) {
      return Row(
        children: const [
          SizedBox(width: 40, child: Text('Set', style: TextStyle(color: AppTheme.textMuted))),
          Expanded(child: Text('Reps', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted))),
          SizedBox(width: 44),
        ],
      );
    } else {
      return Row(
        children: const [
          SizedBox(width: 40, child: Text('Set', style: TextStyle(color: AppTheme.textMuted))),
          Expanded(child: Text('Weight', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted))),
          Expanded(child: Text('Reps', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted))),
          SizedBox(width: 44),
        ],
      );
    }
  }

  Widget _buildSetRow(WorkoutSet workoutSet, int setIndex, bool isDuration, bool isRepsOnly) {
    if (isDuration) {
      return DurationSetRow(
        setIndex: setIndex,
        workoutSet: workoutSet,
        workoutExerciseId: widget.workoutExercise.id!,
        onDeleteRequested: () => _handleDeleteSet(workoutSet),
      );
    } else if (isRepsOnly) {
      return RepsSetRow(
        setIndex: setIndex,
        workoutSet: workoutSet,
        workoutExerciseId: widget.workoutExercise.id!,
        onDeleteRequested: () => _handleDeleteSet(workoutSet),
      );
    } else {
      return SetRow(
        setIndex: setIndex,
        workoutSet: workoutSet,
        workoutExerciseId: widget.workoutExercise.id!,
        onDeleteRequested: () => _handleDeleteSet(workoutSet),
      );
    }
  }

  Future<void> _handleDeleteSet(WorkoutSet workoutSet) async {
    final shouldDelete = await _showConfirmation(
      title: 'Delete set?',
      message: 'This set will be removed from your workout log.',
      confirmLabel: 'Delete',
    );
    if (shouldDelete && mounted) {
      final repo = ref.read(workoutRepositoryProvider);
      await repo.deleteSet(workoutSet.id!);
      ref.invalidate(workoutSetsProvider(widget.workoutExercise.id!));
      // Stats and history will be refreshed by global invalidations or notifier-level logic if needed
      // Actually invalidations should be handled at the notifier level to keep UI lean
      ref.invalidate(workoutStatsProvider(widget.workoutExercise.workoutId));
      ref.invalidate(muscleHistoryProvider);
      ref.invalidate(allWorkoutsProvider);
    }
  }

  Future<void> _handleDeleteExercise(BuildContext context, String exerciseName, String muscleGroupName) async {
    final shouldDelete = await _showConfirmation(
      title: 'Remove exercise?',
      message: 'Remove $muscleGroupName • $exerciseName from this workout? Your logged sets for this exercise will also be removed.',
      confirmLabel: 'Remove',
    );
    if (shouldDelete && mounted) {
      final repo = ref.read(workoutRepositoryProvider);
      await repo.removeExerciseFromWorkout(widget.workoutExercise.id!);
      
      // Invalidate related providers
      ref.invalidate(workoutExercisesProvider(widget.workoutExercise.workoutId));
      ref.invalidate(workoutStatsProvider(widget.workoutExercise.workoutId));
      ref.invalidate(workoutByDateProvider(widget.date));
      ref.invalidate(allWorkoutsProvider);
      ref.invalidate(muscleHistoryProvider);
    }
  }

  Future<bool> _showConfirmation({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: const Color(0xFFFF8D8D),
                        side: const BorderSide(color: Color(0x66FF7A7A), width: 1.5),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;
  }
}
