import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/workout_set.dart';
import '../../providers/repository_providers.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';

const double kSetEntryFieldHeight = 44;
const double kSetEntryFieldRadius = 12;

InputDecoration setEntryDecoration({required String unit, String? hintText}) {
  final borderColor = AppTheme.outline.withValues(alpha: 0.28);
  final borderSide = BorderSide(color: borderColor);
  final borderRadius = BorderRadius.circular(kSetEntryFieldRadius);

  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: AppTheme.textMuted,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    isDense: true,
    filled: true,
    fillColor: AppTheme.surface.withValues(alpha: 0.92),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    border: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    suffixIcon: unit.isEmpty
        ? null
        : SetUnitSuffix(unit: unit, dividerColor: borderColor),
    suffixIconConstraints: const BoxConstraints(
      minHeight: kSetEntryFieldHeight,
      minWidth: 0,
    ),
  );
}

class SetUnitSuffix extends StatelessWidget {
  final String unit;
  final Color dividerColor;

  const SetUnitSuffix({super.key, required this.unit, required this.dividerColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 1, height: 22, color: dividerColor),
        const SizedBox(width: 10),
        Text(
          unit,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

class SetEntryField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final String unit;
  final String? hintText;

  const SetEntryField({
    super.key,
    required this.controller,
    required this.keyboardType,
    required this.textInputAction,
    required this.unit,
    this.focusNode,
    this.inputFormatters,
    this.onSubmitted,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kSetEntryFieldHeight,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        onSubmitted: onSubmitted,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: AppTheme.primary,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        decoration: setEntryDecoration(unit: unit, hintText: hintText),
      ),
    );
  }
}

class SetRow extends ConsumerStatefulWidget {
  final int setIndex;
  final WorkoutSet workoutSet;
  final int workoutExerciseId;
  final VoidCallback onDeleteRequested;
  static final _weightFormat = NumberFormat('0.##');

  const SetRow({
    super.key,
    required this.setIndex,
    required this.workoutSet,
    required this.workoutExerciseId,
    required this.onDeleteRequested,
  });

  @override
  ConsumerState<SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<SetRow> {
  static final _weightInputFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d{0,2}$'),
  );

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _repsFocusNode = FocusNode();

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _syncControllersFromWidget();
  }

  @override
  void didUpdateWidget(covariant SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing &&
        (oldWidget.workoutSet.weight != widget.workoutSet.weight ||
            oldWidget.workoutSet.reps != widget.workoutSet.reps)) {
      _syncControllersFromWidget();
    }
  }

  void _syncControllersFromWidget() {
    final weight = widget.workoutSet.weight ?? 0;
    final reps = widget.workoutSet.reps ?? 0;
    _weightController.text = SetRow._weightFormat.format(weight);
    _repsController.text = '$reps';
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    final w = double.tryParse(_weightController.text) ?? 0;
    final r = int.tryParse(_repsController.text) ?? 0;
    if (w <= 0) {
      _weightFocusNode.requestFocus();
      return;
    }
    if (r <= 0) {
      _repsFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.updateSet(widget.workoutSet.id!, w, r);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));

    if (!mounted) return;
    setState(() {
      _isEditing = false;
    });
    FocusScope.of(context).unfocus();
  }

  Widget _buildRowContent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${widget.setIndex}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: _isEditing
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SetEntryField(
                      controller: _weightController,
                      focusNode: _weightFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        _weightInputFormatter,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onSubmitted: (_) => _repsFocusNode.requestFocus(),
                      unit: 'kg',
                    ),
                  )
                : Text(
                    SetRow._weightFormat.format(widget.workoutSet.weight ?? 0),
                    textAlign: TextAlign.center,
                  ),
          ),
          Expanded(
            child: _isEditing
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SetEntryField(
                      controller: _repsController,
                      focusNode: _repsFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onSubmitted: (_) async => _saveEdits(),
                      unit: 'reps',
                    ),
                  )
                : Text(
                    '${widget.workoutSet.reps ?? 0}',
                    textAlign: TextAlign.center,
                  ),
          ),
          SizedBox(
            width: 44,
            child: IconButton(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              tooltip: _isEditing ? 'Done' : 'Edit',
              onPressed: () async {
                if (_isEditing) {
                  await _saveEdits();
                  return;
                }
                setState(() {
                  _isEditing = true;
                });
                _weightFocusNode.requestFocus();
              },
              icon: Icon(
                _isEditing ? Icons.check_rounded : Icons.edit_outlined,
                color: _isEditing ? const Color(0xFF4ADE80) : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildRowContent(context);
    }

    return Dismissible(
      key: ValueKey(widget.workoutSet.id),
      direction: DismissDirection.endToStart,
      movementDuration: const Duration(milliseconds: 180),
      resizeDuration: const Duration(milliseconds: 160),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEF5350).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        widget.onDeleteRequested();
        return false;
      },
      child: _buildRowContent(context),
    );
  }
}

class RepsSetRow extends ConsumerStatefulWidget {
  final int setIndex;
  final WorkoutSet workoutSet;
  final int workoutExerciseId;
  final VoidCallback onDeleteRequested;

  const RepsSetRow({
    super.key,
    required this.setIndex,
    required this.workoutSet,
    required this.workoutExerciseId,
    required this.onDeleteRequested,
  });

  @override
  ConsumerState<RepsSetRow> createState() => _RepsSetRowState();
}

class _RepsSetRowState extends ConsumerState<RepsSetRow> {
  final TextEditingController _repsController = TextEditingController();
  final FocusNode _repsFocusNode = FocusNode();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _syncControllersFromWidget();
  }

  @override
  void didUpdateWidget(covariant RepsSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.workoutSet.reps != widget.workoutSet.reps) {
      _syncControllersFromWidget();
    }
  }

  void _syncControllersFromWidget() {
    final reps = widget.workoutSet.reps ?? 0;
    _repsController.text = '$reps';
  }

  @override
  void dispose() {
    _repsController.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    final reps = int.tryParse(_repsController.text) ?? 0;
    if (reps <= 0) {
      _repsFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.updateRepsSet(widget.workoutSet.id!, reps);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));

    if (!mounted) return;
    setState(() {
      _isEditing = false;
    });
    FocusScope.of(context).unfocus();
  }

  Widget _buildRowContent(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${widget.setIndex}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: _isEditing
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SetEntryField(
                      controller: _repsController,
                      focusNode: _repsFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      onSubmitted: (_) async => _saveEdits(),
                      unit: 'reps',
                    ),
                  )
                : Text(
                    '${widget.workoutSet.reps ?? 0} reps',
                    textAlign: TextAlign.center,
                  ),
          ),
          SizedBox(
            width: 44,
            child: IconButton(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              tooltip: _isEditing ? 'Done' : 'Edit',
              onPressed: () async {
                if (_isEditing) {
                  await _saveEdits();
                  return;
                }
                setState(() {
                  _isEditing = true;
                });
                _repsFocusNode.requestFocus();
              },
              icon: Icon(
                _isEditing ? Icons.check_rounded : Icons.edit_outlined,
                color: _isEditing ? const Color(0xFF4ADE80) : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildRowContent(context);
    }

    return Dismissible(
      key: ValueKey(widget.workoutSet.id),
      direction: DismissDirection.endToStart,
      movementDuration: const Duration(milliseconds: 180),
      resizeDuration: const Duration(milliseconds: 160),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEF5350).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        widget.onDeleteRequested();
        return false;
      },
      child: _buildRowContent(context),
    );
  }
}

class DurationSetRow extends ConsumerStatefulWidget {
  final int setIndex;
  final WorkoutSet workoutSet;
  final int workoutExerciseId;
  final VoidCallback onDeleteRequested;

  const DurationSetRow({
    super.key,
    required this.setIndex,
    required this.workoutSet,
    required this.workoutExerciseId,
    required this.onDeleteRequested,
  });

  @override
  ConsumerState<DurationSetRow> createState() => _DurationSetRowState();
}

class _DurationSetRowState extends ConsumerState<DurationSetRow> {
  final TextEditingController _minutesController = TextEditingController();
  final TextEditingController _secondsController = TextEditingController();
  final FocusNode _minutesFocusNode = FocusNode();
  final FocusNode _secondsFocusNode = FocusNode();

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _syncControllersFromWidget();
  }

  @override
  void didUpdateWidget(covariant DurationSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing &&
        oldWidget.workoutSet.durationSeconds !=
            widget.workoutSet.durationSeconds) {
      _syncControllersFromWidget();
    }
  }

  void _syncControllersFromWidget() {
    final total = widget.workoutSet.durationSeconds ?? 0;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    _minutesController.text = '$minutes';
    _secondsController.text = '$seconds';
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    _minutesFocusNode.dispose();
    _secondsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    final totalSeconds = (minutes * 60) + seconds;

    if (totalSeconds <= 0) {
      _minutesFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.updateDurationSet(widget.workoutSet.id!, totalSeconds);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));

    if (!mounted) return;
    setState(() {
      _isEditing = false;
    });
    FocusScope.of(context).unfocus();
  }

  String _formatDurationLabel(int totalSeconds) {
    if (totalSeconds <= 0) return '0 sec';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) return '$seconds sec';
    if (seconds == 0) return '$minutes min';
    return '$minutes min $seconds sec';
  }

  Widget _buildRowContent(BuildContext context) {
    final totalSeconds = widget.workoutSet.durationSeconds ?? 0;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${widget.setIndex}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: _isEditing
                ? Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SetEntryField(
                            controller: _minutesController,
                            focusNode: _minutesFocusNode,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            onSubmitted: (_) =>
                                _secondsFocusNode.requestFocus(),
                            unit: 'min',
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SetEntryField(
                            controller: _secondsController,
                            focusNode: _secondsFocusNode,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            onSubmitted: (_) async => _saveEdits(),
                            unit: 'sec',
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    _formatDurationLabel(totalSeconds),
                    textAlign: TextAlign.center,
                  ),
          ),
          SizedBox(
            width: 44,
            child: IconButton(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              tooltip: _isEditing ? 'Done' : 'Edit',
              onPressed: () async {
                if (_isEditing) {
                  await _saveEdits();
                  return;
                }
                setState(() {
                  _isEditing = true;
                });
                _minutesFocusNode.requestFocus();
              },
              icon: Icon(
                _isEditing ? Icons.check_rounded : Icons.edit_outlined,
                color: _isEditing ? const Color(0xFF4ADE80) : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildRowContent(context);
    }

    return Dismissible(
      key: ValueKey(widget.workoutSet.id),
      direction: DismissDirection.endToStart,
      movementDuration: const Duration(milliseconds: 180),
      resizeDuration: const Duration(milliseconds: 160),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEF5350).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        widget.onDeleteRequested();
        return false;
      },
      child: _buildRowContent(context),
    );
  }
}

class AddSetRow extends ConsumerStatefulWidget {
  final int workoutExerciseId;
  final int workoutId;
  final int nextSetIndex;

  const AddSetRow({
    super.key,
    required this.workoutExerciseId,
    required this.workoutId,
    required this.nextSetIndex,
  });

  @override
  ConsumerState<AddSetRow> createState() => _AddSetRowState();
}

class _AddSetRowState extends ConsumerState<AddSetRow> {
  final TextEditingController weightController = TextEditingController();
  final TextEditingController repsController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _repsFocusNode = FocusNode();
  static final _weightInputFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d{0,2}$'),
  );

  @override
  void dispose() {
    weightController.dispose();
    repsController.dispose();
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitSet() async {
    final w = double.tryParse(weightController.text) ?? 0;
    final r = int.tryParse(repsController.text) ?? 0;
    if (w <= 0) {
      _weightFocusNode.requestFocus();
      return;
    }
    if (r <= 0) {
      _repsFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.addSet(widget.workoutExerciseId, w, r);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));
    ref.invalidate(workoutStatsProvider(widget.workoutId));
    
    weightController.clear();
    repsController.clear();
    if (mounted) {
      _weightFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.6),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.nextSetIndex}',
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SetEntryField(
                controller: weightController,
                focusNode: _weightFocusNode,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  _weightInputFormatter,
                  LengthLimitingTextInputFormatter(6),
                ],
                onSubmitted: (_) => _repsFocusNode.requestFocus(),
                hintText: '0',
                unit: 'kg',
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SetEntryField(
                controller: repsController,
                focusNode: _repsFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                onSubmitted: (_) async {
                  await _submitSet();
                },
                hintText: '0',
                unit: 'reps',
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: IconButton.filled(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.check_rounded),
              onPressed: _submitSet,
            ),
          ),
        ],
      ),
    );
  }
}

class AddRepsSetRow extends ConsumerStatefulWidget {
  final int workoutExerciseId;
  final int workoutId;
  final int nextSetIndex;

  const AddRepsSetRow({
    super.key,
    required this.workoutExerciseId,
    required this.workoutId,
    required this.nextSetIndex,
  });

  @override
  ConsumerState<AddRepsSetRow> createState() => _AddRepsSetRowState();
}

class _AddRepsSetRowState extends ConsumerState<AddRepsSetRow> {
  final TextEditingController repsController = TextEditingController();
  final FocusNode _repsFocusNode = FocusNode();

  @override
  void dispose() {
    repsController.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitSet() async {
    final reps = int.tryParse(repsController.text) ?? 0;
    if (reps <= 0) {
      _repsFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.addRepsSet(widget.workoutExerciseId, reps);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));
    ref.invalidate(workoutStatsProvider(widget.workoutId));
    
    repsController.clear();
    if (mounted) {
      _repsFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.6),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.nextSetIndex}',
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SetEntryField(
                controller: repsController,
                focusNode: _repsFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onSubmitted: (_) async => _submitSet(),
                hintText: '0',
                unit: 'reps',
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: IconButton.filled(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.check_rounded),
              onPressed: _submitSet,
            ),
          ),
        ],
      ),
    );
  }
}

class AddDurationSetRow extends ConsumerStatefulWidget {
  final int workoutExerciseId;
  final int workoutId;
  final int nextSetIndex;

  const AddDurationSetRow({
    super.key,
    required this.workoutExerciseId,
    required this.workoutId,
    required this.nextSetIndex,
  });

  @override
  ConsumerState<AddDurationSetRow> createState() => _AddDurationSetRowState();
}

class _AddDurationSetRowState extends ConsumerState<AddDurationSetRow> {
  final TextEditingController minutesController = TextEditingController();
  final TextEditingController secondsController = TextEditingController();
  final FocusNode _minutesFocusNode = FocusNode();
  final FocusNode _secondsFocusNode = FocusNode();

  @override
  void dispose() {
    minutesController.dispose();
    secondsController.dispose();
    _minutesFocusNode.dispose();
    _secondsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitSet() async {
    final minutes = int.tryParse(minutesController.text) ?? 0;
    final seconds = int.tryParse(secondsController.text) ?? 0;
    final totalSeconds = (minutes * 60) + seconds;
    if (totalSeconds <= 0) {
      _minutesFocusNode.requestFocus();
      return;
    }

    final repo = ref.read(workoutRepositoryProvider);
    await repo.addDurationSet(widget.workoutExerciseId, totalSeconds);
    ref.invalidate(workoutSetsProvider(widget.workoutExerciseId));
    ref.invalidate(workoutStatsProvider(widget.workoutId));

    minutesController.clear();
    secondsController.clear();
    if (mounted) {
      _minutesFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.6),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.nextSetIndex}',
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SetEntryField(
                controller: minutesController,
                focusNode: _minutesFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                onSubmitted: (_) => _secondsFocusNode.requestFocus(),
                hintText: '0',
                unit: 'min',
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SetEntryField(
                controller: secondsController,
                focusNode: _secondsFocusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                onSubmitted: (_) async => _submitSet(),
                hintText: '0',
                unit: 'sec',
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: IconButton.filled(
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.check_rounded),
              onPressed: _submitSet,
            ),
          ),
        ],
      ),
    );
  }
}
