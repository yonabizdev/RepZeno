import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../providers/profile_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: CustomScrollView(
            slivers: [
              SliverList.list(
                children: [
                  const _DrawerHeader(),
                  const SizedBox(height: 12),
                  _DrawerTile(
                    icon: Icons.grid_view_rounded,
                    label: 'Dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/');
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Health Insights',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/reports');
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Weight Progress',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/bodyweight');
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'My Progress',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/progress');
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Divider(color: AppTheme.outline, height: 1),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Divider(color: AppTheme.outline, height: 1),
                  ),
                  _DrawerTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile');
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

class _DrawerHeader extends ConsumerWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B3B32), // Dark greenish/teal tint from screenshot
            AppTheme.surfaceElevated,
          ],
          stops: const [0.0, 0.7],
        ),
        border: Border.all(color: AppTheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          profileAsync.when(
            data: (profile) {
              final name = profile?.name;
              final displayName = (name != null && name.trim().isNotEmpty) 
                ? 'Hi $name!' 
                : 'RepZeno';
              return Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              );
            },
            loading: () => const SizedBox(
              height: 32,
              child: Text(
                'Hi ...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            error: (_, __) => const Text(
              'Hi there',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
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
