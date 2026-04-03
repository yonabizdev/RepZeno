import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/weight_log.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_app_bar.dart';
import '../core/extensions.dart';

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
  bool _isSliderMode = false;
  double _sliderPosition = 0.5;
  
  late TransformationController _controllerA;
  late TransformationController _controllerB;
  
  // Track if we are currently propagating a change to avoid infinite loops
  bool _isPropagating = false;

  @override
  void initState() {
    super.initState();
    _controllerA = TransformationController();
    _controllerB = TransformationController();
    
    _controllerA.addListener(_handleControllerAChange);
    _controllerB.addListener(_handleControllerBChange);
  }

  void _handleControllerAChange() {
    if (!_isPropagating) {
      _isPropagating = true;
      _controllerB.value = _controllerA.value;
      _isPropagating = false;
    }
  }

  void _handleControllerBChange() {
    if (!_isPropagating) {
      _isPropagating = true;
      _controllerA.value = _controllerB.value;
      _isPropagating = false;
    }
  }

  void _resetView() {
    setState(() {
      _controllerA.value = Matrix4.identity();
      _controllerB.value = Matrix4.identity();
    });
  }

  @override
  void dispose() {
    _controllerA.removeListener(_handleControllerAChange);
    _controllerB.removeListener(_handleControllerBChange);
    _controllerA.dispose();
    _controllerB.dispose();
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
              _resetView();
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
                  const Text(
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
            position: Alignment.topCenter,
            transformController: _controllerA,
            showBorder: false,
            fit: BoxFit.fitHeight,
          ),
        ),
        const VerticalDivider(width: 2, color: Colors.white24),
        Expanded(
          child: _ComparisonImage(
            path: widget.pathB,
            label: 'AFTER',
            date: widget.dateB,
            position: Alignment.topCenter,
            transformController: _controllerB,
            showBorder: false,
            fit: BoxFit.fitHeight,
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
              // Bottom layer: AFTER Image (now clipped as well)
              ClipRect(
                clipper: _AfterClipper(fraction: _sliderPosition),
                child: _ComparisonImage(
                  path: widget.pathB,
                  label: 'AFTER',
                  date: widget.dateB,
                  position: Alignment.topRight,
                  transformController: _controllerB,
                  showBorder: false,
                  fit: BoxFit.cover,
                  isSlider: true,
                ),
              ),
              // Top layer: BEFORE Image (clipped)
              ClipRect(
                clipper: _BeforeClipper(fraction: _sliderPosition),
                child: _ComparisonImage(
                  path: widget.pathA,
                  label: 'BEFORE',
                  date: widget.dateA,
                  position: Alignment.topLeft,
                  transformController: _controllerA,
                  showBorder: false,
                  fit: BoxFit.cover,
                  isSlider: true,
                ),
              ),
              Positioned(
                left: constraints.maxWidth * _sliderPosition - 1,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              // Draggable Handle (Moved to bottom)
              Positioned(
                left: constraints.maxWidth * _sliderPosition - 22,
                bottom: 40, // Elevated slightly from the very bottom
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chevron_left_rounded, color: AppTheme.primary, size: 20),
                      Icon(Icons.chevron_right_rounded, color: AppTheme.primary, size: 20),
                    ],
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

class _AfterClipper extends CustomClipper<Rect> {
  final double fraction;
  _AfterClipper({required this.fraction});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(size.width * fraction, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_AfterClipper oldClipper) => oldClipper.fraction != fraction;
}

class _ComparisonImage extends ConsumerStatefulWidget {
  final String path;
  final String label;
  final String date;
  final Alignment position;
  final TransformationController? transformController;
  final bool showBorder;
  final BoxFit fit;
  final bool isSlider;

  const _ComparisonImage({
    super.key,
    required this.path,
    required this.label,
    required this.date,
    this.position = Alignment.center,
    this.transformController,
    this.showBorder = false,
    this.fit = BoxFit.contain,
    this.isSlider = false,
  });

  @override
  ConsumerState<_ComparisonImage> createState() => _ComparisonImageState();
}

class _ComparisonImageState extends ConsumerState<_ComparisonImage> {
  bool _centered = false;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  double? _imageAspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(_ComparisonImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    _centered = false;
    _imageStreamListener?.let((l) => _imageStream?.removeListener(l));
    
    final image = FileImage(File(widget.path));
    _imageStream = image.resolve(const ImageConfiguration());
    _imageStreamListener = ImageStreamListener((info, synchronousCall) {
      if (mounted) {
        setState(() {
          _imageAspectRatio = info.image.width / info.image.height;
        });
      }
    });
    _imageStream!.addListener(_imageStreamListener!);
  }

  @override
  void dispose() {
    _imageStreamListener?.let((l) => _imageStream?.removeListener(l));
    super.dispose();
  }

  void _centerInitially(BoxConstraints constraints) {
    if (_centered || widget.transformController == null || _imageAspectRatio == null || widget.isSlider) {
      return;
    }

    if (widget.fit == BoxFit.fitHeight) {
      final imageWidth = constraints.maxHeight * _imageAspectRatio!;
      final viewportWidth = constraints.maxWidth;
      if (imageWidth > viewportWidth) {
        final offset = (imageWidth - viewportWidth) / 2;
        widget.transformController!.value = Matrix4.translationValues(-offset, 0.0, 0.0);
      }
    }
    _centered = true;
  }

  void _handleDoubleTap(Offset localPosition) {
    if (widget.transformController == null) return;

    final currentMatrix = widget.transformController!.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    if (currentScale > 1.1) {
      // Zoom out to 1.0
      widget.transformController!.value = Matrix4.identity();
    } else {
      // Zoom in to 2.5x
      const double zoomLevel = 2.5;
      final x = -localPosition.dx * (zoomLevel - 1);
      final y = -localPosition.dy * (zoomLevel - 1);
      
      final zoomedMatrix = Matrix4.identity()
        ..multiply(Matrix4.translationValues(x, y, 0.0))
        ..multiply(Matrix4.diagonal3Values(zoomLevel, zoomLevel, 1.0));
        
      widget.transformController!.value = zoomedMatrix;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Apply centering only once when size is known
        WidgetsBinding.instance.addPostFrameCallback((_) => _centerInitially(constraints));

        Widget imageWidget = Image.file(
          File(widget.path),
          width: widget.fit == BoxFit.fitHeight ? null : constraints.maxWidth,
          height: constraints.maxHeight,
          alignment: Alignment.center,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppTheme.surfaceMuted,
            child: const Icon(Icons.help_outline_rounded, color: AppTheme.textMuted),
          ),
        );

        if (widget.transformController != null) {
          imageWidget = GestureDetector(
            onDoubleTapDown: (details) => _handleDoubleTap(details.localPosition),
            onDoubleTap: () {}, // Handled by onDoubleTapDown for position
            child: InteractiveViewer(
              constrained: false,
              transformationController: widget.transformController,
              minScale: 1.0,
              maxScale: 4.0,
              clipBehavior: Clip.hardEdge,
              child: imageWidget,
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: widget.showBorder ? BoxDecoration(
                border: Border.all(color: AppTheme.primary, width: 2),
              ) : null,
              child: Center(child: imageWidget),
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Align(
                alignment: widget.position,
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
                          widget.label,
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(DateTime.parse(widget.date)),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        FutureBuilder<WeightLog?>(
                          future: ref.read(profileRepositoryProvider).getWeightLogByDate(widget.date),
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
