import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../providers/profile_provider.dart';
import '../models/user_profile.dart';
import '../models/weight_log.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedChart = 'Weight';
  String _selectedTimeline = '1W';

  int? _calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty) return null;
    try {
      final dob = DateTime.parse(dobString);
      final today = DateTime.now();
      int age = today.year - dob.year;
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title, style: const TextStyle(color: AppTheme.primary)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final weightLogsAsync = ref.watch(weightLogsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Health Reports')),
      body: AppBackdrop(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading reports: $err')),
          data: (profile) {
            return weightLogsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (logs) {
                final double? heightCm = profile?.height;
                final String? gender = profile?.gender;
                final int? age = _calculateAge(profile?.dateOfBirth);
                
                final bool isProfileMissing = heightCm == null || gender == null || age == null;
                final bool isLogsMissing = logs.isEmpty;

                if (isProfileMissing || isLogsMissing) {
                  return _buildEmptyState(context, isProfileMissing: isProfileMissing, isLogsMissing: isLogsMissing);
                }

                return _buildReportsList(context, profile!, age, logs);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required bool isProfileMissing, required bool isLogsMissing}) {
    String message;
    String buttonText;
    String route;
    
    if (isProfileMissing) {
      message = 'Please ensure you have filled out your Gender, Height, and Date of Birth in your Profile to unlock your custom health reports.';
      buttonText = 'Complete Profile';
      route = '/profile';
    } else {
      message = 'Your profile looks great! Please log at least one Bodyweight entry to visualize your tracking progress and metabolic reports.';
      buttonText = 'Log Bodyweight';
      route = '/bodyweight';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 80, color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Not Enough Data',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.push(route),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartToggle(String label) {
    final isSelected = _selectedChart == label;
    return InkWell(
      onTap: () {
        if (!isSelected) {
           setState(() {
              _selectedChart = label;
           });
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineToggle(String label) {
    final isSelected = _selectedTimeline == label;
    return InkWell(
      onTap: () {
        if (!isSelected) {
           setState(() {
              _selectedTimeline = label;
           });
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.outline : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveChart(List<WeightLog> logs, double targetWeight, double heightM) {
    if (logs.isEmpty) return const SizedBox.shrink();

    final isBmi = _selectedChart == 'BMI';
    final targetLine = isBmi ? 24.9 : targetWeight;

    // Filter by timeline
    DateTime now = DateTime.now();
    DateTime? cutoff;
    switch (_selectedTimeline) {
      case '1W': cutoff = now.subtract(const Duration(days: 7)); break;
      case '1M': cutoff = now.subtract(const Duration(days: 30)); break;
      case '3M': cutoff = now.subtract(const Duration(days: 90)); break;
      case '6M': cutoff = now.subtract(const Duration(days: 180)); break;
      case '1Y': cutoff = now.subtract(const Duration(days: 365)); break;
      case 'All': default: cutoff = null; break;
    }

    final filteredLogs = cutoff == null 
        ? logs 
        : logs.where((l) {
            final logDate = DateTime.parse(l.date);
            return logDate.isAfter(cutoff!) || logDate.isAtSameMomentAs(cutoff!);
          }).toList();

    // If no logs in timeframe, just show latest log to avoid empty chart break
    final logsToUse = filteredLogs.isEmpty && logs.isNotEmpty 
        ? [logs.reduce((a, b) => DateTime.parse(a.date).isAfter(DateTime.parse(b.date)) ? a : b)]
        : filteredLogs;

    // Sort chronologically
    final sortedLogs = List<WeightLog>.from(logsToUse)
      ..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

    final List<FlSpot> spots = [];
    double minX = double.maxFinite;
    double maxX = -double.maxFinite;
    double minY = targetLine;
    double maxY = targetLine;

    final Map<double, double> distinctDays = {};

    for (int i = 0; i < sortedLogs.length; i++) {
      final log = sortedLogs[i];
      final date = DateTime.parse(log.date);
      // Map to exact days
      final double x = date.millisecondsSinceEpoch / (1000 * 60 * 60 * 24);
      final double y = isBmi ? log.weight / (heightM * heightM) : log.weight;
      
      distinctDays[x] = y;
    }

    final sortedXKeys = distinctDays.keys.toList()..sort();
    for (final x in sortedXKeys) {
      final y = distinctDays[x]!;
      spots.add(FlSpot(x, y));

      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    if (spots.length == 1) {
      final spot = spots.first;
      spots.insert(0, FlSpot(spot.x - 1, spot.y));
      minX = spot.x - 1;
      maxX = spot.x;
    }

    final yRange = (maxY - minY).abs() < 5 ? 5 : (maxY - minY);
    minY -= yRange * 0.2;
    maxY += yRange * 0.3; 
    
    final xRange = (maxX - minX) == 0 ? 1 : maxX - minX;
    minX -= xRange * 0.05;
    maxX += xRange * 0.05;
    
    final double xInterval = xRange > 0 ? (xRange / 4).ceilToDouble() : 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      height: 420,
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.show_chart_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isBmi ? 'BMI Progress vs Ideal Limit' : 'Weight Progress vs Ideal Goal',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  _buildChartToggle('Weight'),
                  const SizedBox(width: 8),
                  _buildChartToggle('BMI'),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Row(
                     children: [
                       Container(width: 12, height: 4, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
                       const SizedBox(width: 6),
                       const Text('Actual', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                     ],
                   ),
                   const SizedBox(height: 6),
                   Row(
                     children: [
                       Container(width: 12, height: 4, decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(2))),
                       const SizedBox(width: 6),
                       const Text('Ideal', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                     ],
                   ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  drawHorizontalLine: false, // Hide grey line clutter
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: targetLine,
                      color: Colors.tealAccent.withValues(alpha: 0.6),
                      strokeWidth: 2,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 6, bottom: 4),
                        style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        labelResolver: (line) => '${line.y.toStringAsFixed(1)}${isBmi ? "" : " kg"}',
                      ),
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: isBmi ? 2 : 5,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            isBmi ? value.toStringAsFixed(1) : value.toInt().toString(),
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.surfaceElevated,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final textStyle = const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        );
                        final date = DateTime.fromMillisecondsSinceEpoch((touchedSpot.x * 1000 * 60 * 60 * 24).toInt());
                        final dateStr = DateFormat('MMM d, yyyy').format(date);
                        final unit = isBmi ? '' : ' kg';
                        return LineTooltipItem('$dateStr\n${touchedSpot.y.toStringAsFixed(1)}$unit', textStyle);
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppTheme.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true, 
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: AppTheme.primary,
                          strokeWidth: 2,
                          strokeColor: AppTheme.surfaceElevated,
                        );
                      }
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.35),
                          AppTheme.primary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimelineToggle('1W'),
              _buildTimelineToggle('1M'),
              _buildTimelineToggle('3M'),
              _buildTimelineToggle('6M'),
              _buildTimelineToggle('1Y'),
              _buildTimelineToggle('All'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList(BuildContext context, UserProfile profile, int age, List<WeightLog> logs) {
    final heightCm = profile.height!;
    final heightM = heightCm / 100.0;
    
    // Extrapolate latest weight
    final WeightLog latestLog = logs.reduce((curr, next) => DateTime.parse(curr.date).isAfter(DateTime.parse(next.date)) ? curr : next);
    final double weightKg = latestLog.weight;

    // BMI
    final bmi = weightKg / (heightM * heightM);
    
    // BMR (Mifflin-St Jeor)
    double bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    if (profile.gender == 'Male') {
      bmr += 5;
    } else if (profile.gender == 'Female') {
      bmr -= 161;
    } else {
      bmr -= 78;
    }
    
    // IBW (Devine)
    final heightInches = heightCm / 2.54;
    double ibw = 0;
    if (heightInches > 60) {
       final base = profile.gender == 'Female' ? 45.5 : 50.0;
       ibw = base + 2.3 * (heightInches - 60);
    } else {
       ibw = profile.gender == 'Female' ? 45.5 : 50.0;
    }
    
    // Max Heart Rate (Tanaka)
    final maxHr = 208 - (0.7 * age);
    
    final topContentInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, topContentInset, 16, 24),
      children: [
        _buildInteractiveChart(logs, ibw, heightM),
        _buildMetricCard(
          context,
          title: 'Ideal Target Weight',
          value: '${ibw.toStringAsFixed(1)} kg',
          subtitle: 'Devine standard projection',
          icon: Icons.adjust_rounded,
          infoTitle: 'Ideal Body Weight (IBW)',
          infoContent: 'The Devine Formula (1974) calculates a statistically healthy target weight based strictly on your height and biological gender. It serves as an excellent baseline goal if you are looking to trim down to standard athletic proportions.',
        ),
        _buildMetricCard(
          context,
          title: 'Body Mass Index (BMI)',
          value: bmi.toStringAsFixed(1),
          subtitle: _getBmiStatus(bmi),
          icon: Icons.monitor_weight_outlined,
          infoTitle: 'About BMI',
          infoContent: 'Body Mass Index is a simple medical ratio of your weight-to-height. Underweight is < 18.5, Normal is 18.5-24.9, Overweight is 25-29.9, and Obese is 30+. Note: This formula does not account for heavy muscle mass.',
        ),
        _buildMetricCard(
          context,
          title: 'Basal Metabolic Rate (BMR)',
          value: '${bmr.round()} kcal',
          subtitle: 'Calories burned at complete rest',
          icon: Icons.local_fire_department_outlined,
          infoTitle: 'About BMR',
          infoContent: 'Your BMR represents the exact number of calories your body burns per day if you stayed in bed doing absolutely nothing. Calculated tightly for your age, gender, and weight using the Mifflin-St Jeor equation.',
        ),
        _buildMetricCard(
          context,
          title: 'Total Daily Energy',
          value: '${(bmr * 1.55).round()} kcal',
          subtitle: 'Maintenance calories for 3-5 workouts/wk',
          icon: Icons.bolt_rounded,
          infoTitle: 'Total Daily Energy Expenditure',
          infoContent: 'TDEE is your BMR multiplied by an activity factor. If you work out moderately (3-5 times a week), eating this amount of calories will perfectly maintain your weight. Eat roughly 500 kcal less to lose fat, or 300 kcal more to build muscle.',
        ),
        _buildMetricCard(
          context,
          title: 'Fat-Burn Heart Rate',
          value: '${(maxHr * 0.6).round()} - ${(maxHr * 0.7).round()} BPM',
          subtitle: 'Maximum safe HR is ${maxHr.round()} BPM',
          icon: Icons.favorite_border_rounded,
          infoTitle: 'Target Heart Rate Zones',
          infoContent: 'Using the Tanaka medical formula, your estimated maximum heart rate was calculated based on your exact age. The fat burning zone displayed here represents 60-70% of your maximum target limits.',
        ),
      ],
    );
  }

  String _getBmiStatus(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal Weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Widget _buildMetricCard(BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required String infoTitle,
    required String infoContent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppTheme.primary),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.info_outline, color: AppTheme.textMuted, size: 20),
              onPressed: () => _showInfoDialog(context, infoTitle, infoContent),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
          ),
        ],
      ),
    );
  }
}
