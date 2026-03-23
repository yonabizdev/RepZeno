import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: CustomScrollView(
            slivers: [
              SliverList.list(
                children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0x33FF8C24), Color(0x2217E7B1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppTheme.outline),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/branding/app_icon.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RepZeno',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Lift smarter. Track cleaner.',
                            style: TextStyle(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _DrawerTile(
                icon: Icons.grid_view_rounded,
                label: 'Dashboard',
                onTap: () {
                  Navigator.pop(context);
                  context.go('/');
                },
              ),
              _DrawerTile(
                icon: Icons.query_stats_rounded,
                label: 'Muscle History',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/history/1');
                },
              ),
              _DrawerTile(
                icon: Icons.fitness_center_rounded,
                label: 'Manage Exercises',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/manage-exercises');
                },
              ),
              _DrawerTile(
                icon: Icons.settings_rounded,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(context);
                  context.push('/settings');
                },
              ),
                ],
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(height: 16),
                    Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.outline),
                ),
                child: const Text(
                  'Stay consistent. Small workouts still count.',
                  style: TextStyle(color: AppTheme.textMuted, height: 1.4),
                ),
              ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        tileColor: AppTheme.surface.withValues(alpha: 0.75),
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }
}
