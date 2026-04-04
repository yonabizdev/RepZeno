import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/workout/exercise_card.dart';
import '../widgets/workout/workout_header.dart';
import '../widgets/workout/workout_tip_banner.dart';

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
    final topContentInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final parsedDate = DateTime.tryParse(widget.date);
    final titleDate = parsedDate == null
        ? widget.date
        : DateFormat('EEE, dd MMM yyyy').format(parsedDate);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          title: const Text('Workout Log'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/'),
            tooltip: 'Back to Dashboard',
          ),
        ),
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
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, topContentInset, 16, bottomInset + 24),
      children: [
        if (_showWorkoutTip) ...[
          WorkoutTipBanner(onClose: _dismissWorkoutTip),
          const SizedBox(height: 16),
        ],
        WorkoutHeader(dateLabel: titleDate, exerciseCount: null),
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
                onPressed: () => context.push('/add-exercise/date/${widget.date}'),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded, size: 18),
                ),
                label: const Text('Add New Exercise'),
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
        final statsAsync = ref.watch(workoutStatsProvider(workoutId));
        final stats = statsAsync.maybeWhen(
          data: (s) => s,
          orElse: () => {'exerciseCount': exercises.length, 'setCount': 0},
        );

        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, topContentInset, 16, bottomInset + 24),
          children: [
            if (_showWorkoutTip) ...[
              WorkoutTipBanner(onClose: _dismissWorkoutTip),
              const SizedBox(height: 16),
            ],
            WorkoutHeader(
              dateLabel: titleDate,
              exerciseCount: stats['exerciseCount'],
              setCount: stats['setCount'] ?? 0,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-exercise/$workoutId'),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded, size: 18),
              ),
              label: const Text('Add New Exercise'),
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
                (exercise) => ExerciseCard(workoutExercise: exercise, date: widget.date),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}
