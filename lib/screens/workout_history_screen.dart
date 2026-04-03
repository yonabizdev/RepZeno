import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/muscle_group.dart';
import '../providers/exercise_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/selection_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../providers/workout_actions_provider.dart';
import 'package:go_router/go_router.dart';

class WorkoutHistoryScreen extends ConsumerStatefulWidget {
  final int muscleGroupId;
  const WorkoutHistoryScreen({super.key, required this.muscleGroupId});

  @override
  ConsumerState<WorkoutHistoryScreen> createState() =>
      _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends ConsumerState<WorkoutHistoryScreen> {
  static const _historyTipPrefKey = 'workout_history_tip_hidden';
  bool _showHistoryTip = true;
  int _selectedMuscleGroupId = 1;
  final DateFormat _historyDateFormat = DateFormat('EEE, dd MMM yyyy');
  final NumberFormat _weightFormat = NumberFormat('0.##');

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

  @override
  void initState() {
    super.initState();
    _selectedMuscleGroupId = widget.muscleGroupId;
    _loadTipPreference();
  }

  Future<void> _loadTipPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isHidden = prefs.getBool(_historyTipPrefKey) ?? false;
    if (mounted) {
      setState(() {
        _showHistoryTip = !isHidden;
      });
    }
  }

  Future<void> _dismissHistoryTip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_historyTipPrefKey, true);
    if (mounted) {
      setState(() {
        _showHistoryTip = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);
    final topContentInset =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final historyAsync = ref.watch(
      muscleHistoryProvider(_selectedMuscleGroupId),
    );
    final isAscending = ref.watch(sortSetsAscendingProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Workout History')),
      body: AppBackdrop(
        child: Column(
          children: [
            SizedBox(height: topContentInset),
            muscleGroupsAsync.when(
              data: (muscleGroups) => _buildFilterSection(muscleGroups),
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Unable to load muscle groups right now.'),
              ),
            ),
            if (_showHistoryTip)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _HistoryTipBanner(onClose: _dismissHistoryTip),
              ),
            Expanded(
              child: historyAsync.when(
                data: (history) => _buildHistoryContent(history, isAscending: isAscending),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(List<MuscleGroup> muscleGroups) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Muscle Group',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SelectionField(
              label:
                  muscleGroups
                      .cast<MuscleGroup?>()
                      .firstWhere(
                        (group) => group?.id == _selectedMuscleGroupId,
                        orElse: () => null,
                      )
                      ?.name ??
                  'Select muscle group',
              onTap: () async {
                final picked = await showSelectionSheet<MuscleGroup>(
                  context: context,
                  title: 'Select Muscle Group',
                  items: muscleGroups,
                  labelBuilder: (muscleGroup) => muscleGroup.name,
                  isSelected: (muscleGroup) =>
                      muscleGroup.id == _selectedMuscleGroupId,
                );
                if (picked != null && picked.id != _selectedMuscleGroupId) {
                  setState(() {
                    _selectedMuscleGroupId = picked.id!;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent(List<Map<String, dynamic>> history, {required bool isAscending}) {
    if (history.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.outline),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.query_stats_rounded,
                  size: 56,
                  color: AppTheme.secondary,
                ),
                SizedBox(height: 14),
                Text(
                  'No workout history yet',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Once you log workouts for this muscle group, your sets will appear here as a clean timeline.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final grouped = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final row in history) {
      final date = row['workout_date'] as String;
      final exerciseName = row['exercise_name'] as String;
      grouped.putIfAbsent(date, () => {});
      grouped[date]!.putIfAbsent(exerciseName, () => []);
      grouped[date]![exerciseName]!.add(row);
    }

    final dates = grouped.keys.toList();
    final totalSets = history.length;
    final totalDays = dates.length;
    final totalExercises = grouped.values.fold<int>(
      0,
      (count, exerciseMap) => count + exerciseMap.length,
    );

    final showTip = _showHistoryTip;

    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: dates.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _HistoryHero(
              days: totalDays,
              exercises: totalExercises,
              sets: totalSets,
            ),
          );
        }

        final dateIndex = index - 1;
        final date = dates[dateIndex];
        final exercises = grouped[date]!;
        final parsedDate = DateTime.tryParse(date);
        final displayDate = parsedDate == null
            ? date
            : _historyDateFormat.format(parsedDate);
        final daySetCount = exercises.values.fold<int>(
          0,
          (count, sets) => count + sets.length,
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
                        Text(
                          displayDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${exercises.length} exercises • $daySetCount sets',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final exerciseIds = exercises.values
                          .map((sets) => (sets.first['exercise_id'] as num).toInt())
                          .toList();
                      await ref.read(workoutActionsProvider).copySessionToToday(exerciseIds);
                      if (context.mounted) {
                        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                        context.push('/workout/$today');
                      }
                    },
                    icon: const Icon(Icons.content_copy_rounded, color: AppTheme.secondary, size: 20),
                    tooltip: 'Copy all exercises to today',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...exercises.entries.map((entry) {
                final exerciseName = entry.key;
                final sets = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exerciseName,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${sets.length} sets',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              final exerciseId = (sets.first['exercise_id'] as num).toInt();
                              await ref.read(workoutActionsProvider).copyExerciseToToday(exerciseId);
                              if (context.mounted) {
                                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                                context.push('/workout/$today');
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 20),
                            tooltip: 'Add to today\'s workout',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(sets.length, (index) {
                        final setIndex = isAscending ? index : sets.length - 1 - index;
                        final set = sets[setIndex];
                        final trackingType =
                            (set['tracking_type'] as String?) ?? 'weight_reps';
                        final durationSeconds =
                            (set['set_duration_seconds'] as num?)?.toInt();
                        final weight = (set['set_weight'] as num?)?.toDouble();
                        final reps = (set['set_reps'] as num?)?.toInt();
                        final isDuration =
                            trackingType == 'duration' ||
                            durationSeconds != null;
                        final isRepsOnly =
                            trackingType == 'reps' ||
                            (!isDuration && weight == null && reps != null);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.18,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${setIndex + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: isDuration
                                    ? Text(
                                        _formatDurationLabel(
                                          durationSeconds ?? 0,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : isRepsOnly
                                    ? Text(
                                        '${reps ?? 0} reps',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : Text(
                                        '${_weightFormat.format(weight ?? 0)} kg',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                              if (!isDuration && !isRepsOnly)
                                Text(
                                  '${reps ?? 0} reps',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryTipBanner extends StatelessWidget {
  final VoidCallback onClose;

  const _HistoryTipBanner({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Tip:',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Quickly build your workout from history:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const _TipItem(
                  icon: Icons.content_copy_rounded,
                  color: AppTheme.secondary,
                  text: 'Copy all exercises from a previous session.',
                ),
                const SizedBox(height: 6),
                const _TipItem(
                  icon: Icons.add_circle_outline_rounded,
                  color: AppTheme.primary,
                  text: 'Add a single exercise to today\'s log.',
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Dismiss tip',
          ),
        ],
      ),
    );
  }
}


class _HistoryHero extends StatelessWidget {
  final int days;
  final int exercises;
  final int sets;

  const _HistoryHero({
    required this.days,
    required this.exercises,
    required this.sets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
          const Row(
            children: [
              Icon(Icons.timeline_rounded, size: 18, color: AppTheme.secondary),
              SizedBox(width: 8),
              Text(
                'Timeline Overview',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HistoryMetric(label: 'Days', value: '$days'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HistoryMetric(label: 'Exercises', value: '$exercises'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HistoryMetric(label: 'Sets', value: '$sets'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HistoryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
        ],
      ),
    );
  }
}
class _TipItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _TipItem({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
