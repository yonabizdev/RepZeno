import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/glass_app_bar.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topContentInset =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Privacy & Data')),
      body: AppBackdrop(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topContentInset, 16, 24),
          children: [
            const _PrivacyHero(),
            const SizedBox(height: 16),
            const _PrivacySection(
              title: 'What RepZeno stores',
              points: [
                'Workout dates, exercises, sets, weight, reps, and duration logs.',
                'Custom exercises you create inside the app.',
                'A few local UI preferences, such as dismissed tips.',
              ],
            ),
            const SizedBox(height: 14),
            const _PrivacySection(
              title: 'How the data is used',
              points: [
                'Your data is used only to power workout logging and history inside the app.',
                'RepZeno does not require an account and does not sync your workout data to RepZeno servers.',
                'The app does not use analytics, ads, or cross-app tracking.',
              ],
            ),
            const SizedBox(height: 14),
            _PrivacySection(
              title: 'Backup and storage',
              points: [
                'The workout database is stored locally on your device.',
                if (!kIsWeb && Platform.isAndroid)
                  'Android cloud backup and device-transfer backup are disabled for app data.',
                if (!kIsWeb && Platform.isIOS)
                  'On iPhone and iPad, the workout database is excluded from iCloud backup.',
              ],
            ),
            const SizedBox(height: 14),
            const _PrivacySection(
              title: 'Delete your data',
              points: [
                'You can remove individual workout entries and custom exercises from inside the app.',
                'To remove all local RepZeno data, uninstall the app or clear the app storage from your device settings.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyHero extends StatelessWidget {
  const _PrivacyHero();

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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppTheme.secondary),
              SizedBox(width: 10),
              Text(
                'Local-first privacy',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'RepZeno is built to keep your workout history on your device. It does not create an account, upload your exercise data to RepZeno servers, or use advertising trackers.',
            style: TextStyle(color: AppTheme.textMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final List<String> points;

  const _PrivacySection({required this.title, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(Icons.circle, size: 8, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        height: 1.45,
                      ),
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
