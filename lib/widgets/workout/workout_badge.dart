import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class WorkoutBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? secondaryIcon;
  final String? secondaryLabel;

  const WorkoutBadge({
    super.key,
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
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.secondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (secondaryIcon != null && secondaryLabel != null) ...[
            const SizedBox(width: 16),
            Icon(secondaryIcon!, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
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
