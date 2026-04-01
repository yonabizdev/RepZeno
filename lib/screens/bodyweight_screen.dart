import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/user_profile.dart';
import '../models/weight_log.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/glass_app_bar.dart';

class BodyweightScreen extends ConsumerStatefulWidget {
  const BodyweightScreen({super.key});

  @override
  ConsumerState<BodyweightScreen> createState() => _BodyweightScreenState();
}

class _BodyweightScreenState extends ConsumerState<BodyweightScreen> {
  final _weightController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  double? _calculateIdealWeight(UserProfile? profile) {
    if (profile == null || profile.height == null || profile.gender == null) return null;
    
    final double heightCm = profile.height!;
    final heightInches = heightCm / 2.54;
    double ibw = 0;
    double devineBase = 50.0;
    
    if (profile.gender == 'Female') {
      devineBase = 45.5;
    } else if (profile.gender != 'Male') {
      devineBase = 47.75; // Median for non-binary representations
    }
    
    if (heightInches > 60) {
       ibw = devineBase + 2.3 * (heightInches - 60);
    } else {
       ibw = devineBase;
    }
    return ibw;
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _addWeightLog() async {
    final weightText = _weightController.text.trim();
    final weight = double.tryParse(weightText);

    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight in KGs.')),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final currentLogs = ref.read(weightLogsProvider).value ?? [];
    
    if (currentLogs.any((l) => l.date.startsWith(dateStr))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A weight log already exists for this date. Please edit or delete it instead.')),
      );
      return;
    }

    final log = WeightLog(
      date: dateStr,
      weight: weight,
      createdAt: DateTime.now().toIso8601String(),
    );

    await ref.read(weightLogsProvider.notifier).addLog(log);
    _weightController.clear();
    FocusScope.of(context).unfocus();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight logged successfully!')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: AppTheme.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _editWeightLog(WeightLog log) async {
    final editWeightController = TextEditingController(text: log.weight.toString());
    DateTime editDate = DateTime.parse(log.date);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text('Edit Weight Log'),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editWeightController,
                    decoration: InputDecoration(
                      labelText: 'Weight (kg)',
                      prefixIcon: const Icon(Icons.monitor_weight_outlined),
                      filled: true,
                      fillColor: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: editDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppTheme.primary,
                                onPrimary: Colors.white,
                                surface: AppTheme.surface,
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() {
                          editDate = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM d, yyyy').format(editDate),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final updatedWeight = double.tryParse(editWeightController.text.trim());
                          if (updatedWeight == null || updatedWeight <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid weight.')),
                            );
                            return;
                          }

                          final newDateStr = DateFormat('yyyy-MM-dd').format(editDate);
                          final currentLogs = ref.read(weightLogsProvider).value ?? [];
                          
                          if (currentLogs.any((l) => l.id != log.id && l.date.startsWith(newDateStr))) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Another weight log already exists for this date.')),
                              );
                            }
                            return;
                          }

                          final updatedLog = WeightLog(
                            id: log.id,
                            date: newDateStr,
                            weight: updatedWeight,
                            createdAt: log.createdAt,
                          );

                          await ref.read(weightLogsProvider.notifier).updateLog(updatedLog);
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Weight updated successfully!')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Update'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final weightLogsAsync = ref.watch(weightLogsProvider);
    final topContentInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Weight Progress')),
      body: AppBackdrop(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topContentInset, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log New Weight',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          decoration: InputDecoration(
                            labelText: 'Weight (kg)',
                            prefixIcon: const Icon(Icons.monitor_weight_outlined),
                            filled: true,
                            fillColor: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM d').format(_selectedDate),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _addWeightLog,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Log Weight', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12), // reduced gap between the form and the list
            Container(
              padding: const EdgeInsets.all(16), // reduced inner padding
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'RECENT LOGS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4), // reduced gap behind title
                  weightLogsAsync.when(
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                    error: (err, stack) => Text('Error loading weights: $err'),
                    data: (logs) {
                      final profile = ref.watch(userProfileProvider).value;
                      final idealWeight = _calculateIdealWeight(profile);

                      if (logs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No weight logs yet.\nStart tracking today!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted, height: 1.5),
                            ),
                          ),
                        );
                      }
                      
                      return ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const Divider(color: AppTheme.outline, height: 1),
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final date = DateTime.parse(log.date);
                          
                          double? prevWeight;
                          if (index + 1 < logs.length) {
                            prevWeight = logs[index + 1].weight;
                          }
                          
                          IconData trendIcon = Icons.horizontal_rule_rounded;
                          Color trendColor = AppTheme.textMuted;
                          
                          double? diff;
                          if (prevWeight != null) {
                            diff = log.weight - prevWeight;
                            
                            bool isMovingTowardsIdeal = false;
                            if (idealWeight != null) {
                              final double currentDist = (log.weight - idealWeight).abs();
                              final double prevDist = (prevWeight - idealWeight).abs();
                              // Green if current is strictly closer to ideal than previous
                              isMovingTowardsIdeal = currentDist < prevDist;
                              
                              if (isMovingTowardsIdeal) {
                                trendIcon = log.weight > prevWeight ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
                                trendColor = Colors.greenAccent;
                              } else {
                                trendIcon = log.weight > prevWeight ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
                                trendColor = Colors.redAccent;
                              }
                            } else {
                              // Standard Fallback: Loss is green, Gain is red
                              if (log.weight > prevWeight) {
                                trendIcon = Icons.arrow_upward_rounded;
                                trendColor = Colors.redAccent;
                              } else if (log.weight < prevWeight) {
                                trendIcon = Icons.arrow_downward_rounded;
                                trendColor = Colors.greenAccent;
                              }
                            }
                          }
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: trendColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(trendIcon, color: trendColor, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${log.weight} kg',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      DateFormat('MMM d, yyyy').format(date),
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: AppTheme.textMuted, size: 18),
                                  onPressed: () => _editWeightLog(log),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  onPressed: () {
                                    ref.read(weightLogsProvider.notifier).deleteLog(log.id!);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
