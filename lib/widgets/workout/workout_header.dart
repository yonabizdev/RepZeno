import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'workout_badge.dart';

class WorkoutHeader extends StatelessWidget {
  final String dateLabel;
  final int? exerciseCount;
  final int setCount;

  const WorkoutHeader({
    super.key,
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
                const WorkoutBadge(
                  icon: Icons.fitness_center_rounded,
                  label: 'Ready to start',
                )
              else
                WorkoutBadge(
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
