import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_tracking_type.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';
import '../providers/exercise_provider.dart';
import '../providers/repository_providers.dart';
import '../providers/workout_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';

class WorkoutLogScreen extends ConsumerStatefulWidget {
  final String date;
  const WorkoutLogScreen({super.key, required this.date});

  @override
  ConsumerState<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends ConsumerState<WorkoutLogScreen> {
  static const _workoutTipPrefKey = 'workout_log_tip_hidden';
  bool _showWorkoutTip = true;

  @override
  void initState() {
    super.initState();
    _loadWorkoutTipPreference();
  }

  Future<void> _loadWorkoutTipPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isHidden = prefs.getBool(_workoutTipPrefKey) ?? false;
    if (mounted) {
      setState(() {
        _showWorkoutTip = !isHidden;
      });
    }
  }

  Future<void> _dismissWorkoutTip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_workoutTipPrefKey, true);
    if (mounted) {
      setState(() {
        _showWorkoutTip = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workoutAsync = ref.watch(workoutByDateProvider(widget.date));
    final topContentInset =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final parsedDate = DateTime.tryParse(widget.date);
    final titleDate = parsedDate == null
        ? widget.date
        : DateFormat('EEE, dd MMM yyyy').format(parsedDate);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Workout Log')),
      body: AppBackdrop(
        child: workoutAsync.when(
          data: (workout) {
            if (workout == null) {
              return _buildEmptyState(context, ref, titleDate, topContentInset);
            }
            return _buildWorkoutDetails(
              context,
              ref,
              workout.id!,
              titleDate,
              topContentInset,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    String titleDate,
    double topContentInset,
  ) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, topContentInset, 16, bottomInset + 24),
      children: [
        if (_showWorkoutTip) ...[
          _WorkoutTipBanner(onClose: _dismissWorkoutTip),
          const SizedBox(height: 16),
        ],
        _WorkoutHeader(dateLabel: titleDate, exerciseCount: null),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/branding/app_icon.png',
                  width: 84,
                  height: 84,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No exercises logged yet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Start this workout by adding your first exercise. You can track weight, reps, time, and progress from here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, height: 1.5),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  if (context.mounted) {
                    context.push('/add-exercise/date/${widget.date}');
                  }
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Exercise'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutDetails(
    BuildContext context,
    WidgetRef ref,
    int workoutId,
    String titleDate,
    double topContentInset,
  ) {
    final exercisesAsync = ref.watch(workoutExercisesProvider(workoutId));
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return exercisesAsync.when(
      data: (exercises) {
        int totalSets = 0;
        for (final ex in exercises) {
          final count = ref.watch(workoutSetsProvider(ex.id!)).maybeWhen(
            data: (sets) => sets.length,
            orElse: () => 0,
          );
          totalSets += count;
        }

        return ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            topContentInset,
            16,
            bottomInset + 24,
          ),
          children: [
            if (_showWorkoutTip) ...[
              _WorkoutTipBanner(onClose: _dismissWorkoutTip),
              const SizedBox(height: 16),
            ],
            _WorkoutHeader(
              dateLabel: titleDate,
              exerciseCount: exercises.length,
              setCount: totalSets,
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/add-exercise/$workoutId');
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Exercise'),
              ),
            ),
            const SizedBox(height: 14),
            if (exercises.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTheme.outline),
                ),
                child: const Text(
                  'No exercises added yet. Use the button above to start this workout.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              )
            else
              ...exercises.map(
                (exercise) =>
                    _ExerciseCard(workoutExercise: exercise, date: widget.date),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _WorkoutHeader extends StatelessWidget {
  final String dateLabel;
  final int? exerciseCount;
  final int setCount;

  const _WorkoutHeader({
    required this.dateLabel,
    required this.exerciseCount,
    this.setCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xE61A2533), Color(0xD9101723)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session Overview',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateLabel,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (exerciseCount == null || exerciseCount == 0)
                const _WorkoutBadge(
                  icon: Icons.fitness_center_rounded,
                  label: 'Ready to start',
                )
              else
                _WorkoutBadge(
                  icon: Icons.fitness_center_rounded,
                  label: '$exerciseCount Exercises',
                  secondaryIcon: Icons.local_fire_department_rounded,
                  secondaryLabel: '$setCount Sets',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? secondaryIcon;
  final String? secondaryLabel;

  const _WorkoutBadge({
    required this.icon,
    required this.label,
    this.secondaryIcon,
    this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (secondaryIcon != null && secondaryLabel != null) ...[
            const SizedBox(width: 16),
            Icon(secondaryIcon, size: 16, color: AppTheme.secondary),
            const SizedBox(width: 6),
            Text(
              secondaryLabel!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkoutTipBanner extends StatelessWidget {
  final VoidCallback onClose;

  const _WorkoutTipBanner({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: AppTheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick tip',
                  style: TextStyle(fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text:
                            'Newest exercise appears first so you can keep logging without scrolling.\n',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      TextSpan(
                        text:
                            'Swipe left on a set row to delete it with confirmation.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Dismiss tip',
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends ConsumerStatefulWidget {
  final WorkoutExercise workoutExercise;
  final String date;

  const _ExerciseCard({required this.workoutExercise, required this.date});

  @override
  ConsumerState<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<_ExerciseCard> {
  List<WorkoutSet>? _optimisticSets;

  List<WorkoutSet> _visibleSets(List<WorkoutSet> providerSets) {
    final optimisticSets = _optimisticSets;
    if (optimisticSets == null) {
      return providerSets;
    }

    if (_sameSetSequence(optimisticSets, providerSets)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _optimisticSets != null) {
          setState(() {
            _optimisticSets = null;
          });
        }
      });
      return providerSets;
    }

    return optimisticSets;
  }

  bool _sameSetSequence(List<WorkoutSet> a, List<WorkoutSet> b) {
    if (a.length != b.length) {
      return false;
    }

    for (int i = 0; i < a.length; i++) {
      if (_setSignature(a[i]) != _setSignature(b[i])) {
        return false;
      }
    }

    return true;
  }

  String _setSignature(WorkoutSet set) {
    return [
      set.createdAt,
      set.weight?.toString() ?? '',
      set.reps?.toString() ?? '',
      set.durationSeconds?.toString() ?? '',
    ].join('|');
  }

  void _invalidateSetData() {
    ref.invalidate(workoutSetsProvider(widget.workoutExercise.id!));
    ref.invalidate(muscleHistoryProvider);
    ref.invalidate(allWorkoutsProvider);
  }

  void _removeOptimisticSet(
    WorkoutSet workoutSet,
    List<WorkoutSet> visibleSets,
  ) {
    setState(() {
      _optimisticSets = visibleSets
          .where((set) => set.id != workoutSet.id)
          .toList();
    });
  }

  void _restoreOptimisticSet(
    WorkoutSet workoutSet,
    List<WorkoutSet> visibleSets,
  ) {
    final nextSets = [...visibleSets];
    final insertIndex = nextSets.indexWhere(
      (set) => _compareSetOrder(workoutSet, set) < 0,
    );

    if (insertIndex == -1) {
      nextSets.add(workoutSet);
    } else {
      nextSets.insert(insertIndex, workoutSet);
    }

    setState(() {
      _optimisticSets = nextSets;
    });
  }

  int _compareSetOrder(WorkoutSet a, WorkoutSet b) {
    final createdAtComparison = a.createdAt.compareTo(b.createdAt);
    if (createdAtComparison != 0) {
      return createdAtComparison;
    }

    final aId = a.id ?? 1 << 30;
    final bId = b.id ?? 1 << 30;
    return aId.compareTo(bId);
  }

  Future<void> _handleDeleteSet(
    BuildContext context,
    WorkoutSet workoutSet,
    List<WorkoutSet> visibleSets,
  ) async {
    final shouldDelete = await _showDeleteConfirmation(
      context,
      title: 'Delete set?',
      message: 'This set will be removed from your workout log.',
      confirmLabel: 'Delete',
    );
    if (!shouldDelete || !context.mounted || !mounted) {
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();
    _removeOptimisticSet(workoutSet, visibleSets);

    try {
      await repo.deleteSet(workoutSet.id!);
      _invalidateSetData();
    } catch (_) {
      if (mounted) {
        setState(() {
          _optimisticSets = null;
        });
      }
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not delete the set.')),
        );
      }
      return;
    }

    if (!context.mounted || !mounted) {
      return;
    }

    final setsAfterDelete = visibleSets
        .where((set) => set.id != workoutSet.id)
        .toList();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Expanded(
              child: Text(
                'Set deleted',
                style: TextStyle(
                  color: Color(0xFF4ADE80),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                messenger.hideCurrentSnackBar();
                _restoreOptimisticSet(workoutSet, setsAfterDelete);

                try {
                  if (workoutSet.durationSeconds != null) {
                    await repo.addDurationSet(
                      widget.workoutExercise.id!,
                      workoutSet.durationSeconds!,
                      createdAt: workoutSet.createdAt,
                    );
                  } else if (workoutSet.weight == null &&
                      workoutSet.reps != null) {
                    await repo.addRepsSet(
                      widget.workoutExercise.id!,
                      workoutSet.reps!,
                      createdAt: workoutSet.createdAt,
                    );
                  } else {
                    await repo.addSet(
                      widget.workoutExercise.id!,
                      workoutSet.weight ?? 0,
                      workoutSet.reps ?? 0,
                      createdAt: workoutSet.createdAt,
                    );
                  }
                  _invalidateSetData();
                } catch (_) {
                  if (mounted) {
                    setState(() {
                      _optimisticSets = null;
                    });
                  }
                  if (context.mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Could not restore the set.'),
                      ),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('UNDO'),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setsAsync = ref.watch(
      workoutSetsProvider(widget.workoutExercise.id!),
    );
    final allExercisesAsync = ref.watch(allExercisesProvider);
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);

    String exerciseName = 'Loading...';
    String muscleGroupName = 'Loading...';
    ExerciseTrackingType trackingType = ExerciseTrackingType.weightReps;
    if (allExercisesAsync.hasValue) {
      final match = allExercisesAsync.value!
          .where((e) => e.id == widget.workoutExercise.exerciseId)
          .firstOrNull;
      if (match != null) {
        exerciseName = match.name;
        trackingType = match.trackingType;
        if (muscleGroupsAsync.hasValue) {
          final muscleMatch = muscleGroupsAsync.value!
              .where((mg) => mg.id == match.muscleGroupId)
              .firstOrNull;
          if (muscleMatch != null) {
            muscleGroupName = muscleMatch.name;
          }
        }
      }
    }

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
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x33FF6B6B),
                  foregroundColor: const Color(0xFFFF8D8D),
                  side: const BorderSide(color: Color(0x66FF7A7A)),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final shouldDelete = await _showDeleteConfirmation(
                    context,
                    title: 'Remove exercise?',
                    message:
                        'Remove $muscleGroupName • $exerciseName from this workout? Your logged sets for this exercise will also be removed.',
                    confirmLabel: 'Remove',
                  );
                  if (!shouldDelete || !context.mounted) {
                    return;
                  }
                  final repo = ref.read(workoutRepositoryProvider);
                  await repo.removeExerciseFromWorkout(
                    widget.workoutExercise.id!,
                  );
                  ref.invalidate(
                    workoutExercisesProvider(widget.workoutExercise.workoutId),
                  );
                  ref.invalidate(workoutByDateProvider(widget.date));
                  ref.invalidate(allWorkoutsProvider);
                  ref.invalidate(muscleHistoryProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          isDuration
              ? Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        'Set',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Duration',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                    SizedBox(width: 44),
                  ],
                )
              : isRepsOnly
              ? Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        'Set',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Reps',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                    SizedBox(width: 44),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        'Set',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Weight',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Reps',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ),
                    SizedBox(width: 44),
                  ],
                ),
          const Divider(height: 22),
          setsAsync.when(
            data: (sets) {
              final visibleSets = _visibleSets(sets);
              final isAscending = ref.watch(sortSetsAscendingProvider);
              final displayIndices = isAscending
                  ? List.generate(visibleSets.length, (i) => i)
                  : List.generate(visibleSets.length, (i) => i).reversed.toList();

              final addSetRow = isDuration
                  ? _AddDurationSetRow(
                      workoutExerciseId: widget.workoutExercise.id!,
                      nextSetIndex: visibleSets.length + 1,
                    )
                  : isRepsOnly
                  ? _AddRepsSetRow(
                      workoutExerciseId: widget.workoutExercise.id!,
                      nextSetIndex: visibleSets.length + 1,
                    )
                  : _AddSetRow(
                      workoutExerciseId: widget.workoutExercise.id!,
                      nextSetIndex: visibleSets.length + 1,
                    );

              return Column(
                children: [
                  if (!isAscending) addSetRow,
                  for (final i in displayIndices)
                    isDuration
                        ? _DurationSetRow(
                            setIndex: i + 1,
                            workoutSet: visibleSets[i],
                            workoutExerciseId: widget.workoutExercise.id!,
                            onDeleteRequested: () => _handleDeleteSet(
                              context,
                              visibleSets[i],
                              visibleSets,
                            ),
                          )
                        : isRepsOnly
                        ? _RepsSetRow(
                            setIndex: i + 1,
                            workoutSet: visibleSets[i],
                            workoutExerciseId: widget.workoutExercise.id!,
                            onDeleteRequested: () => _handleDeleteSet(
                              context,
                              visibleSets[i],
                              visibleSets,
                            ),
                          )
                        : _SetRow(
                            setIndex: i + 1,
                            workoutSet: visibleSets[i],
                            workoutExerciseId: widget.workoutExercise.id!,
                            onDeleteRequested: () => _handleDeleteSet(
                              context,
                              visibleSets[i],
                              visibleSets,
                            ),
                          ),
                  if (isAscending) addSetRow,
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

const double _kSetEntryFieldHeight = 44;
const double _kSetEntryFieldRadius = 12;

InputDecoration _setEntryDecoration({required String unit, String? hintText}) {
  final borderColor = AppTheme.outline.withValues(alpha: 0.28);
  final borderSide = BorderSide(color: borderColor);
  final borderRadius = BorderRadius.circular(_kSetEntryFieldRadius);

  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: AppTheme.textMuted,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    isDense: true,
    filled: true,
    fillColor: AppTheme.surface.withValues(alpha: 0.92),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    border: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    suffixIcon: unit.isEmpty
        ? null
        : _SetUnitSuffix(unit: unit, dividerColor: borderColor),
    suffixIconConstraints: const BoxConstraints(
      minHeight: _kSetEntryFieldHeight,
      minWidth: 0,
    ),
  );
}

class _SetUnitSuffix extends StatelessWidget {
  final String unit;
  final Color dividerColor;

  const _SetUnitSuffix({required this.unit, required this.dividerColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 1, height: 22, color: dividerColor),
        const SizedBox(width: 10),
        Text(
          unit,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

class _SetEntryField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final String unit;
  final String? hintText;

  const _SetEntryField({
    required this.controller,
    required this.keyboardType,
    required this.textInputAction,
    required this.unit,
    this.focusNode,
    this.inputFormatters,
    this.onSubmitted,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kSetEntryFieldHeight,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        onSubmitted: onSubmitted,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: AppTheme.primary,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        decoration: _setEntryDecoration(unit: unit, hintText: hintText),
      ),
    );
  }
}

class _SetRow extends ConsumerStatefulWidget {
  final int setIndex;
  final WorkoutSet workoutSet;
  final int workoutExerciseId;
  final Future<void> Function() onDeleteRequested;
  static final _weightFormat = NumberFormat('0.##');

  const _SetRow({
    required this.setIndex,
    required this.workoutSet,
    required this.workoutExerciseId,
    required this.onDeleteRequested,
  });

  @override
  ConsumerState<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<_SetRow> {
  static final _weightInputFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d{0,2}$'),
  );

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _repsFocusNode = FocusNode();

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _syncControllersFromWidget();
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing &&
        (oldWidget.workoutSet.weight != widget.workoutSet.weight ||
            oldWidget.workoutSet.reps != widget.workoutSet.reps)) {
      _syncControllersFromWidget();
    }
  }

  void _syncControllersFromWidget() {
    final weight = widget.workoutSet.weight ?? 0;
    final reps = widget.workoutSet.reps ?? 0;
    _weightController.text = _SetRow._weightFormat.format(weight);
    _repsController.text = '$reps';
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    final w = double.tryParse(_weightController.text) ?? 0;
    final r = int.tryParse(_repsController.text) ?? 0;
    if (w <= 0 && r <= 0) {
      _weightFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.updateSet(widget.workoutSet.id!, w, r);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));
    ref.invalidate(muscleHistoryProvider);
    ref.invalidate(allWorkoutsProvider);

    if (!mounted) {
      return;
    }
    setState(() {
      _isEditing = false;
    });
    FocusScope.of(context).unfocus();
  }

  Widget _buildRowContent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${widget.setIndex}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: _isEditing
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _SetEntryField(
                      controller: _weightController,
                      focusNode: _weightFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        _weightInputFormatter,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onSubmitted: (_) => _repsFocusNode.requestFocus(),
                      unit: 'kg',
                    ),
                  )
                : Text(
                    _SetRow._weightFormat.format(widget.workoutSet.weight ?? 0),
                    textAlign: TextAlign.center,
                  ),
          ),
          Expanded(
            child: _isEditing
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _SetEntryField(
                      controller: _repsController,
                      focusNode: _repsFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onSubmitted: (_) async => _saveEdits(),
                      unit: 'reps',
                    ),
                  )
                : Text(
                    '${widget.workoutSet.reps ?? 0}',
                    textAlign: TextAlign.center,
                  ),
          ),
          SizedBox(
            width: 44,
            child: IconButton(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              tooltip: _isEditing ? 'Done' : 'Edit',
              onPressed: () async {
                if (_isEditing) {
                  await _saveEdits();
                  return;
                }
                setState(() {
                  _isEditing = true;
                });
                _weightFocusNode.requestFocus();
              },
              icon: Icon(
                _isEditing ? Icons.check_rounded : Icons.edit_outlined,
                color: _isEditing ? AppTheme.primary : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildRowContent(context);
    }

    return Dismissible(
      key: ValueKey(widget.workoutSet.id),
      direction: DismissDirection.endToStart,
      movementDuration: const Duration(milliseconds: 180),
      resizeDuration: const Duration(milliseconds: 160),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        await widget.onDeleteRequested();
        return false;
      },
      child: _buildRowContent(context),
    );
  }
}

class _RepsSetRow extends ConsumerStatefulWidget {
  final int setIndex;
  final WorkoutSet workoutSet;
  final int workoutExerciseId;
  final Future<void> Function() onDeleteRequested;

  const _RepsSetRow({
    required this.setIndex,
    required this.workoutSet,
    required this.workoutExerciseId,
    required this.onDeleteRequested,
  });

  @override
  ConsumerState<_RepsSetRow> createState() => _RepsSetRowState();
}

class _RepsSetRowState extends ConsumerState<_RepsSetRow> {
  final TextEditingController _repsController = TextEditingController();
  final FocusNode _repsFocusNode = FocusNode();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _syncControllersFromWidget();
  }

  @override
  void didUpdateWidget(covariant _RepsSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.workoutSet.reps != widget.workoutSet.reps) {
      _syncControllersFromWidget();
    }
  }

  void _syncControllersFromWidget() {
    final reps = widget.workoutSet.reps ?? 0;
    _repsController.text = '$reps';
  }

  @override
  void dispose() {
    _repsController.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    final reps = int.tryParse(_repsController.text) ?? 0;
    if (reps <= 0) {
      _repsFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.updateRepsSet(widget.workoutSet.id!, reps);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));
    ref.invalidate(muscleHistoryProvider);

    if (!mounted) {
      return;
    }
    setState(() {
      _isEditing = false;
    });
    FocusScope.of(context).unfocus();
  }

  Widget _buildRowContent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${widget.setIndex}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: _isEditing
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _SetEntryField(
                      controller: _repsController,
                      focusNode: _repsFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onSubmitted: (_) async => _saveEdits(),
                      unit: 'reps',
                    ),
                  )
                : Text(
                    '${widget.workoutSet.reps ?? 0} reps',
                    textAlign: TextAlign.center,
                  ),
          ),
          SizedBox(
            width: 44,
            child: IconButton(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              tooltip: _isEditing ? 'Done' : 'Edit',
              onPressed: () async {
                if (_isEditing) {
                  await _saveEdits();
                  return;
                }
                setState(() {
                  _isEditing = true;
                });
                _repsFocusNode.requestFocus();
              },
              icon: Icon(
                _isEditing ? Icons.check_rounded : Icons.edit_outlined,
                color: _isEditing ? AppTheme.primary : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildRowContent(context);
    }

    return Dismissible(
      key: ValueKey(widget.workoutSet.id),
      direction: DismissDirection.endToStart,
      movementDuration: const Duration(milliseconds: 180),
      resizeDuration: const Duration(milliseconds: 160),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        await widget.onDeleteRequested();
        return false;
      },
      child: _buildRowContent(context),
    );
  }
}

String _formatDurationLabel(int totalSeconds) {
  if (totalSeconds <= 0) {
    return '0 sec';
  }

  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;

  if (minutes == 0) {
    return '$seconds sec';
  }

  if (seconds == 0) {
    return '$minutes min';
  }

  return '$minutes min $seconds sec';
}

class _DurationSetRow extends ConsumerStatefulWidget {
  final int setIndex;
  final WorkoutSet workoutSet;
  final int workoutExerciseId;
  final Future<void> Function() onDeleteRequested;

  const _DurationSetRow({
    required this.setIndex,
    required this.workoutSet,
    required this.workoutExerciseId,
    required this.onDeleteRequested,
  });

  @override
  ConsumerState<_DurationSetRow> createState() => _DurationSetRowState();
}

class _DurationSetRowState extends ConsumerState<_DurationSetRow> {
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();
  final FocusNode _minutesFocusNode = FocusNode();
  final FocusNode _secondsFocusNode = FocusNode();

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _syncControllersFromWidget();
  }

  @override
  void didUpdateWidget(covariant _DurationSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing &&
        oldWidget.workoutSet.durationSeconds !=
            widget.workoutSet.durationSeconds) {
      _syncControllersFromWidget();
    }
  }

  void _syncControllersFromWidget() {
    final total = widget.workoutSet.durationSeconds ?? 0;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    _minutesController.text = '$minutes';
    _secondsController.text = '$seconds';
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    _minutesFocusNode.dispose();
    _secondsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    final totalSeconds = (minutes * 60) + seconds;

    if (totalSeconds <= 0) {
      _minutesFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.updateDurationSet(widget.workoutSet.id!, totalSeconds);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));
    ref.invalidate(muscleHistoryProvider);

    if (!mounted) {
      return;
    }
    setState(() {
      _isEditing = false;
    });
    FocusScope.of(context).unfocus();
  }

  Widget _buildRowContent(BuildContext context) {
    final totalSeconds = widget.workoutSet.durationSeconds ?? 0;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${widget.setIndex}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: _isEditing
                ? Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _SetEntryField(
                            controller: _minutesController,
                            focusNode: _minutesFocusNode,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            onSubmitted: (_) =>
                                _secondsFocusNode.requestFocus(),
                            unit: 'min',
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _SetEntryField(
                            controller: _secondsController,
                            focusNode: _secondsFocusNode,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            onSubmitted: (_) async => _saveEdits(),
                            unit: 'sec',
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    _formatDurationLabel(totalSeconds),
                    textAlign: TextAlign.center,
                  ),
          ),
          SizedBox(
            width: 44,
            child: IconButton(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              tooltip: _isEditing ? 'Done' : 'Edit',
              onPressed: () async {
                if (_isEditing) {
                  await _saveEdits();
                  return;
                }
                setState(() {
                  _isEditing = true;
                });
                _minutesFocusNode.requestFocus();
              },
              icon: Icon(
                _isEditing ? Icons.check_rounded : Icons.edit_outlined,
                color: _isEditing ? AppTheme.primary : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildRowContent(context);
    }

    return Dismissible(
      key: ValueKey(widget.workoutSet.id),
      direction: DismissDirection.endToStart,
      movementDuration: const Duration(milliseconds: 180),
      resizeDuration: const Duration(milliseconds: 160),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        await widget.onDeleteRequested();
        return false;
      },
      child: _buildRowContent(context),
    );
  }
}

Future<bool> _showDeleteConfirmation(
  BuildContext context, {
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
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

class _AddSetRow extends ConsumerStatefulWidget {
  final int workoutExerciseId;
  final int nextSetIndex;

  const _AddSetRow({
    required this.workoutExerciseId,
    required this.nextSetIndex,
  });

  @override
  ConsumerState<_AddSetRow> createState() => _AddSetRowState();
}

class _AddRepsSetRow extends ConsumerStatefulWidget {
  final int workoutExerciseId;
  final int nextSetIndex;

  const _AddRepsSetRow({
    required this.workoutExerciseId,
    required this.nextSetIndex,
  });

  @override
  ConsumerState<_AddRepsSetRow> createState() => _AddRepsSetRowState();
}

class _AddDurationSetRow extends ConsumerStatefulWidget {
  final int workoutExerciseId;
  final int nextSetIndex;

  const _AddDurationSetRow({
    required this.workoutExerciseId,
    required this.nextSetIndex,
  });

  @override
  ConsumerState<_AddDurationSetRow> createState() => _AddDurationSetRowState();
}

class _AddDurationSetRowState extends ConsumerState<_AddDurationSetRow> {
  final TextEditingController minutesController = TextEditingController();
  final TextEditingController secondsController = TextEditingController();
  final FocusNode _minutesFocusNode = FocusNode();
  final FocusNode _secondsFocusNode = FocusNode();

  @override
  void dispose() {
    minutesController.dispose();
    secondsController.dispose();
    _minutesFocusNode.dispose();
    _secondsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitSet() async {
    final minutes = int.tryParse(minutesController.text) ?? 0;
    final seconds = int.tryParse(secondsController.text) ?? 0;
    final totalSeconds = (minutes * 60) + seconds;
    if (totalSeconds <= 0) {
      _minutesFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.addDurationSet(widget.workoutExerciseId, totalSeconds);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));
    ref.invalidate(muscleHistoryProvider);
    ref.invalidate(allWorkoutsProvider);
    minutesController.clear();
    secondsController.clear();
    if (mounted) {
      _minutesFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.6),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.nextSetIndex}',
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _SetEntryField(
                controller: minutesController,
                focusNode: _minutesFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                onSubmitted: (_) => _secondsFocusNode.requestFocus(),
                hintText: '0',
                unit: 'min',
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _SetEntryField(
                controller: secondsController,
                focusNode: _secondsFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                onSubmitted: (_) async => _submitSet(),
                hintText: '0',
                unit: 'sec',
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: IconButton.filled(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.check_rounded),
              onPressed: _submitSet,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddRepsSetRowState extends ConsumerState<_AddRepsSetRow> {
  final TextEditingController repsController = TextEditingController();
  final FocusNode _repsFocusNode = FocusNode();

  @override
  void dispose() {
    repsController.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitSet() async {
    final reps = int.tryParse(repsController.text) ?? 0;
    if (reps <= 0) {
      _repsFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.addRepsSet(widget.workoutExerciseId, reps);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));
    ref.invalidate(muscleHistoryProvider);
    ref.invalidate(allWorkoutsProvider);
    repsController.clear();
    if (mounted) {
      _repsFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.6),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.nextSetIndex}',
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _SetEntryField(
                controller: repsController,
                focusNode: _repsFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onSubmitted: (_) async => _submitSet(),
                hintText: '0',
                unit: 'reps',
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: IconButton.filled(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.check_rounded),
              onPressed: _submitSet,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSetRowState extends ConsumerState<_AddSetRow> {
  final TextEditingController weightController = TextEditingController();
  final TextEditingController repsController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _repsFocusNode = FocusNode();
  static final _weightInputFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d{0,2}$'),
  );

  @override
  void dispose() {
    weightController.dispose();
    repsController.dispose();
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitSet() async {
    final w = double.tryParse(weightController.text) ?? 0;
    final r = int.tryParse(repsController.text) ?? 0;
    if (w <= 0 && r <= 0) {
      _weightFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.addSet(widget.workoutExerciseId, w, r);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));
    ref.invalidate(muscleHistoryProvider);
    ref.invalidate(allWorkoutsProvider);
    weightController.clear();
    repsController.clear();
    if (mounted) {
      _weightFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.6),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.nextSetIndex}',
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _SetEntryField(
                controller: weightController,
                focusNode: _weightFocusNode,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  _weightInputFormatter,
                  LengthLimitingTextInputFormatter(6),
                ],
                onSubmitted: (_) => _repsFocusNode.requestFocus(),
                hintText: '0',
                unit: 'kg',
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _SetEntryField(
                controller: repsController,
                focusNode: _repsFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                onSubmitted: (_) async {
                  await _submitSet();
                },
                hintText: '0',
                unit: 'reps',
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: IconButton.filled(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.check_rounded),
              onPressed: _submitSet,
            ),
          ),
        ],
      ),
    );
  }
}
