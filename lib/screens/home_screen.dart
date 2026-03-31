import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/workout.dart';
import '../providers/exercise_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/app_drawer.dart';
import '../widgets/glass_app_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _dashboardTipPrefKey = 'dashboard_tip_hidden';

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showDashboardTip = true;
  late final AnimationController _introController;
  late final Animation<double> _heroOpacity;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _calendarOpacity;
  late final Animation<Offset> _calendarSlide;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heroOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.62, curve: Curves.easeOutCubic),
    );
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.0, 0.62, curve: Curves.easeOutCubic),
          ),
        );
    _calendarOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    );
    _calendarSlide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _loadDashboardTipPreference();
    _introController.forward();
  }

  Future<void> _loadDashboardTipPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isHidden = prefs.getBool(_dashboardTipPrefKey) ?? false;
    if (mounted) {
      setState(() {
        _showDashboardTip = !isHidden;
      });
    }
  }

  Future<void> _dismissDashboardTip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dashboardTipPrefKey, true);
    if (mounted) {
      setState(() {
        _showDashboardTip = false;
      });
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

  Widget _buildCalendarDayCell(
    DateTime day,
    Map<String, int> workoutCountByDate, {
    required bool isOutside,
  }) {
    return _CalendarDayCell(
      dayNumber: day.day,
      workoutCount: workoutCountByDate[_dateKey(day)] ?? 0,
      isOutside: isOutside,
      isToday: isSameDay(day, DateTime.now()),
      isSelected: isSameDay(_selectedDay, day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workoutsAsync = ref.watch(allWorkoutsProvider);
    final workouts = workoutsAsync.when(
      data: (workouts) => workouts,
      loading: () => const <Workout>[],
      error: (_, stackTrace) => const <Workout>[],
    );
    final workoutCountByDate = <String, int>{};
    final topContentInset =
        MediaQuery.paddingOf(context).top + kToolbarHeight + 10;

    for (final workout in workouts) {
      workoutCountByDate.update(
        workout.date,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final completedDayCount = workoutCountByDate.length;
    final todayKey = _dateKey(DateTime.now());

    final profileAsync = ref.watch(userProfileProvider);
    String greeting = 'RepZeno';
    profileAsync.whenData((profile) {
      if (profile?.name != null && profile!.name!.isNotEmpty) {
        final firstName = profile.name!.split(' ').first;
        greeting = 'Hi, $firstName!';
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(
          greeting,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      drawer: const AppDrawer(),
      body: AppBackdrop(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topContentInset, 16, 28),
          children: [
            if (_showDashboardTip) ...[
              _TipBanner(onClose: _dismissDashboardTip),
              const SizedBox(height: 16),
            ],
            FadeTransition(
              opacity: _heroOpacity,
              child: SlideTransition(
                position: _heroSlide,
                child: _HeroPanel(
                  completedDayCount: completedDayCount,
                  onLogToday: () => context.push('/workout/$todayKey'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _calendarOpacity,
              child: SlideTransition(
                position: _calendarSlide,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(
                      colors: [Color(0xF5141D28), Color(0xF00F1621)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: AppTheme.outlineStrong),
                    boxShadow: [
                      const BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                      BoxShadow(
                        color: AppTheme.secondary.withValues(alpha: 0.06),
                        blurRadius: 26,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: CalendarFormat.month,
                        rowHeight: 56,
                        daysOfWeekHeight: 30,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        availableGestures: AvailableGestures.horizontalSwipe,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                          context.push('/workout/${_dateKey(selectedDay)}');
                        },
                        eventLoader: (day) {
                          final count = workoutCountByDate[_dateKey(day)] ?? 0;
                          return List<String>.filled(count, 'workout');
                        },
                        calendarStyle: const CalendarStyle(
                          isTodayHighlighted: false,
                          markersMaxCount: 0,
                          canMarkersOverflow: false,
                          defaultDecoration: BoxDecoration(),
                          weekendDecoration: BoxDecoration(),
                          outsideDecoration: BoxDecoration(),
                          todayDecoration: BoxDecoration(),
                          selectedDecoration: BoxDecoration(),
                          cellMargin: EdgeInsets.all(2),
                          cellPadding: EdgeInsets.zero,
                          tablePadding: EdgeInsets.zero,
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                          weekendStyle: TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          headerPadding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                          leftChevronMargin: EdgeInsets.zero,
                          rightChevronMargin: EdgeInsets.zero,
                          leftChevronPadding: EdgeInsets.zero,
                          rightChevronPadding: EdgeInsets.zero,
                          titleTextStyle: Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                          leftChevronIcon: const _CalendarChevron(
                            icon: Icons.chevron_left_rounded,
                          ),
                          rightChevronIcon: const _CalendarChevron(
                            icon: Icons.chevron_right_rounded,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) =>
                              _buildCalendarDayCell(
                                day,
                                workoutCountByDate,
                                isOutside: false,
                              ),
                          todayBuilder: (context, day, focusedDay) =>
                              _buildCalendarDayCell(
                                day,
                                workoutCountByDate,
                                isOutside: false,
                              ),
                          selectedBuilder: (context, day, focusedDay) =>
                              _buildCalendarDayCell(
                                day,
                                workoutCountByDate,
                                isOutside: false,
                              ),
                          outsideBuilder: (context, day, focusedDay) =>
                              _buildCalendarDayCell(
                                day,
                                workoutCountByDate,
                                isOutside: true,
                              ),
                          markerBuilder: (context, day, events) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final int completedDayCount;
  final VoidCallback onLogToday;

  const _HeroPanel({
    required this.completedDayCount,
    required this.onLogToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xF41A2635), Color(0xF00E1520)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.outlineStrong),
        boxShadow: [
          const BoxShadow(
            color: Color(0x26000000),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: -32,
            left: -18,
            child: _HeroGlow(size: 160, color: Color(0x2B17E7B1)),
          ),
          const Positioned(
            right: -28,
            bottom: -46,
            child: _HeroGlow(size: 210, color: Color(0x30FF8C24)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.outlineStrong),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.secondary.withValues(alpha: 0.08),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/branding/app_icon.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
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
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            height: 1.02,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Lift smarter. Track cleaner.',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            height: 1.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DaysLoggedPill(daysLogged: completedDayCount),
              const SizedBox(height: 16),
              _PressableCtaButton(onPressed: onLogToday),
            ],
          ),
        ],
      ),
    );
  }
}

class _DaysLoggedPill extends StatelessWidget {
  final int daysLogged;

  const _DaysLoggedPill({required this.daysLogged});

  @override
  Widget build(BuildContext context) {
    final label = daysLogged == 1 ? '1 day logged' : '$daysLogged days logged';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outlineStrong),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Progress',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PressableCtaButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _PressableCtaButton({required this.onPressed});

  @override
  State<_PressableCtaButton> createState() => _PressableCtaButtonState();
}

class _PressableCtaButtonState extends State<_PressableCtaButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) {
      return;
    }
    setState(() {
      _pressed = pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(
                  alpha: _pressed ? 0.18 : 0.28,
                ),
                blurRadius: _pressed ? 18 : 26,
                spreadRadius: _pressed ? 0 : 1,
                offset: Offset(0, _pressed ? 8 : 12),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: widget.onPressed,
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Start Today\'s Workout'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarChevron extends StatelessWidget {
  final IconData icon;

  const _CalendarChevron({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineStrong),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int dayNumber;
  final int workoutCount;
  final bool isOutside;
  final bool isToday;
  final bool isSelected;

  const _CalendarDayCell({
    required this.dayNumber,
    required this.workoutCount,
    required this.isOutside,
    required this.isToday,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasWorkout = workoutCount > 0;
    final markerColor = isSelected ? Colors.white : AppTheme.secondary;
    Color textColor;

    if (isOutside) {
      textColor = Colors.white24;
    } else if (isSelected) {
      textColor = Colors.white;
    } else if (isToday) {
      textColor = Colors.white;
    } else {
      textColor = Colors.white.withValues(alpha: 0.94);
    }

    final decoration = BoxDecoration(
      color: isSelected
          ? null
          : hasWorkout
          ? AppTheme.surfaceMuted.withValues(alpha: 0.78)
          : isToday
          ? AppTheme.surfaceElevated.withValues(alpha: 0.88)
          : Colors.transparent,
      gradient: isSelected
          ? const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primarySoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isSelected
            ? Colors.transparent
            : hasWorkout
            ? AppTheme.secondary.withValues(alpha: 0.65)
            : isToday
            ? AppTheme.outlineStrong
            : Colors.transparent,
        width: hasWorkout || isToday ? 1.2 : 1,
      ),
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ]
          : hasWorkout
          ? [
              BoxShadow(
                color: AppTheme.secondary.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    );

    return SizedBox(
      width: 48,
      height: 54,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: AnimatedScale(
              scale: isSelected ? 1 : 0.98,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: 46,
                height: 46,
                decoration: decoration,
                child: Center(
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isSelected || isToday
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isToday && !isSelected)
            Positioned(
              top: 6,
              right: 8,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppTheme.primarySoft,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          if (hasWorkout)
            Positioned(
              bottom: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  math.min(workoutCount, 3),
                  (index) => Container(
                    width: workoutCount > 1 ? 8 : 6,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: markerColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _HeroGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.55,
              spreadRadius: size * 0.08,
            ),
          ],
        ),
      ),
    );
  }
}

class _TipBanner extends StatelessWidget {
  final VoidCallback onClose;

  const _TipBanner({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outlineStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline_rounded, color: AppTheme.secondary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick tip',
                  style: TextStyle(fontWeight: FontWeight.w400),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap any calendar date to review past lifts or log a new workout.',
                  style: TextStyle(color: AppTheme.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Dismiss tip',
          ),
        ],
      ),
    );
  }
}
