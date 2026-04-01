import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';

class QuickHistorySheet extends ConsumerWidget {
  final int exerciseId;
  final String exerciseName;
  final int muscleGroupId;
  final String currentDate;

  const QuickHistorySheet({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroupId,
    required this.currentDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(exerciseHistoryProvider(exerciseId));
    final dateFormat = DateFormat('EEE, dd MMM yyyy');
    final weightFormat = NumberFormat('0.##');

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfacePanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.outlineStrong,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.history_rounded, color: AppTheme.secondary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'Previous Performances',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: historyAsync.when(
              data: (allHistory) {
                final history = allHistory.where((row) {
                  final rowDate =
                      DateTime.tryParse(row['workout_date'] as String);
                  final curr = DateTime.tryParse(currentDate);
                  if (rowDate == null || curr == null) return false;
                  return rowDate.isBefore(curr);
                }).toList();

                if (history.isEmpty) {
                  return _buildEmptyState();
                }

                final grouped = _groupHistoryByDate(history);
                final dates = grouped.keys.toList();
                
                // Only show last 5 sessions for "Quick" view
                final displayDates = dates.take(5).toList();

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayDates.length,
                  itemBuilder: (context, index) {
                    final date = displayDates[index];
                    final sets = grouped[date]!;
                    final parsedDate = DateTime.tryParse(date);
                    final displayDate = parsedDate == null
                        ? date
                        : dateFormat.format(parsedDate);

                    return _buildSessionCard(displayDate, sets, weightFormat);
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, st) => Center(child: Text('Error loading history: $e')),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/history/$muscleGroupId');
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('View Full Muscle History'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupHistoryByDate(
    List<Map<String, dynamic>> history,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in history) {
      final date = row['workout_date'] as String;
      grouped.putIfAbsent(date, () => []);
      grouped[date]!.add(row);
    }
    return grouped;
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outline),
      ),
      child: const Column(
        children: [
          Icon(Icons.query_stats_rounded, size: 48, color: AppTheme.textMuted),
          SizedBox(height: 16),
          Text(
            'No history yet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          SizedBox(height: 4),
          Text(
            'Previous logs for this exercise will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(
    String date,
    List<Map<String, dynamic>> sets,
    NumberFormat weightFormat,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppTheme.secondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sets.asMap().entries.map((entry) {
              final setIndex = entry.key + 1;
              final set = entry.value;
              final trackingType = set['tracking_type'] as String?;
              final weight = (set['set_weight'] as num?)?.toDouble();
              final reps = (set['set_reps'] as num?)?.toInt();
              final duration = (set['set_duration_seconds'] as num?)?.toInt();

              String label = '';
              if (trackingType == 'duration' || duration != null) {
                label = _formatDuration(duration ?? 0);
              } else if (weight == null || weight == 0) {
                label = '${reps ?? 0} reps';
              } else {
                label = '${weightFormat.format(weight)}kg × ${reps ?? 0}';
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2), width: 0.5),
                      ),
                      child: Text(
                        '$setIndex',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0s';
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }
}
