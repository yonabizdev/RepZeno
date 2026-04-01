import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/weight_log.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_app_bar.dart';

class ComparisonScreen extends StatefulWidget {
  final String pathA;
  final String dateA;
  final String pathB;
  final String dateB;

  const ComparisonScreen({
    super.key,
    required this.pathA,
    required this.dateA,
    required this.pathB,
    required this.dateB,
  });

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  bool _isSliderMode = true;
  double _sliderPosition = 0.5;
  final TransformationController _syncController = TransformationController();

  @override
  void dispose() {
    _syncController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: GlassAppBar(
        title: const Text('Transformation'),
        actions: [
          IconButton(
            icon: Icon(
              _isSliderMode ? Icons.view_sidebar_rounded : Icons.splitscreen_rounded,
              color: AppTheme.primary,
            ),
            tooltip: _isSliderMode ? 'Switch to Side-by-Side' : 'Switch to Slider Mode',
            onPressed: () {
              setState(() {
                _isSliderMode = !_isSliderMode;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isSliderMode 
                ? _buildSliderMode() 
                : _buildSideBySideMode(),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Visual progress doesn’t lie.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep pushing. Consistency is key.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontStyle: FontStyle.italic,
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

  Widget _buildSideBySideMode() {
    return Row(
      children: [
        Expanded(
          child: _ComparisonImage(
            path: widget.pathA,
            label: 'BEFORE',
            date: widget.dateA,
            position: Alignment.center,
            transformController: _syncController,
          ),
        ),
        const VerticalDivider(width: 2, color: Colors.white24),
        Expanded(
          child: _ComparisonImage(
            path: widget.pathB,
            label: 'AFTER',
            date: widget.dateB,
            position: Alignment.center,
            transformController: _syncController,
          ),
        ),
      ],
    );
  }

  Widget _buildSliderMode() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _sliderPosition += details.delta.dx / constraints.maxWidth;
              _sliderPosition = _sliderPosition.clamp(0.0, 1.0);
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Bottom layer: AFTER Image
              _ComparisonImage(
                path: widget.pathB,
                label: 'AFTER',
                date: widget.dateB,
                position: Alignment.topRight,
              ),
              // Top layer: BEFORE Image (clipped)
              ClipRect(
                clipper: _BeforeClipper(fraction: _sliderPosition),
                child: _ComparisonImage(
                  path: widget.pathA,
                  label: 'BEFORE',
                  date: widget.dateA,
                  position: Alignment.topLeft,
                ),
              ),
              // Draggable Divider Line
              Positioned(
                left: constraints.maxWidth * _sliderPosition - 16,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Container(
                    width: 4,
                    color: Colors.white,
                    child: Center(
                      child: Container(
                        height: 48,
                        width: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: const Icon(Icons.compare_arrows_rounded, color: AppTheme.primary, size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BeforeClipper extends CustomClipper<Rect> {
  final double fraction;
  _BeforeClipper({required this.fraction});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * fraction, size.height);
  }

  @override
  bool shouldReclip(_BeforeClipper oldClipper) => oldClipper.fraction != fraction;
}

class _ComparisonImage extends ConsumerWidget {
  final String path;
  final String label;
  final String date;
  final Alignment position;
  final TransformationController? transformController;

  const _ComparisonImage({
    required this.path,
    required this.label,
    required this.date,
    this.position = Alignment.center,
    this.transformController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget imageWidget = Image.file(
          File(path),
          height: constraints.maxHeight, // Forces the image to exactly match the screen height
          fit: BoxFit.fitHeight, // Maintains aspect ratio, computing a natural width
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppTheme.surfaceMuted,
            child: const Icon(Icons.help_outline_rounded, color: AppTheme.textMuted),
          ),
        );

        if (transformController != null) {
          imageWidget = InteractiveViewer(
            constrained: false, // Essential to allow the uncropped width to be horizontally scrollable
            transformationController: transformController,
            minScale: 1.0,
            maxScale: 4.0,
            clipBehavior: Clip.hardEdge,
            child: imageWidget,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            Positioned(
              top: 16, // Shifted from 40 to 16
              left: 0,
              right: 0,
              child: Align(
                alignment: position,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(DateTime.parse(date)),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        FutureBuilder<WeightLog?>(
                          future: ref.read(profileRepositoryProvider).getWeightLogByDate(date),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${snapshot.data!.weight} kg',
                                  style: const TextStyle(
                                    color: AppTheme.secondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
