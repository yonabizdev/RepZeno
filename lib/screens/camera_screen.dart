import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/progress_photo_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  bool _isCapturing = false;
  
  String? _referencePath;
  double _overlayOpacity = 0.3;
  bool _showReferencePicker = false;
  int _selectedCameraIndex = 0;

  // Advanced Camera Features
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseScale = 1.0;
  // veryHigh maps directly to hardware-level 1080p capture (matches gallery import limits)
  ResolutionPreset _resolutionPreset = ResolutionPreset.veryHigh;
  FlashMode _flashMode = FlashMode.off; // Defaulting to off as per typical 'Ultra' high quality preference
  bool _isExposureSliderVisible = false;
  double _minExposure = 0.0;
  double _maxExposure = 0.0;
  double _currentExposure = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isDismissed = ref.read(cameraTipDismissedProvider);
      if (!isDismissed) {
        _showHelpDialog();
      }
    });
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      _controller = CameraController(
        _cameras[_selectedCameraIndex],
        _resolutionPreset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller?.initialize();
      
      if (_controller != null && _controller!.value.isInitialized) {
        _minZoom = await _controller!.getMinZoomLevel();
        _maxZoom = await _controller!.getMaxZoomLevel();
        _minExposure = await _controller!.getMinExposureOffset();
        _maxExposure = await _controller!.getMaxExposureOffset();
        
        await _controller!.setFlashMode(_flashMode);
      }

      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    
    if (_controller != null) {
      await _controller!.dispose();
    }

    _initializeCamera();
  }

  Future<void> _setZoom(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    final newZoom = zoom.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(newZoom);
    setState(() {
      _currentZoom = newZoom;
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentZoom;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    if (_controller == null || _cameras.isEmpty) return;
    
    await _setZoom(_baseScale * details.scale);
  }

  Future<void> _onTapFocus(TapUpDetails details, BoxConstraints constraints) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    
    await _controller!.setFocusPoint(offset);
    await _controller!.setExposurePoint(offset);
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true; // Briefly show loading to prevent double taps
    });

    try {
      final XFile image = await _controller!.takePicture();
      // Fast return. We rely on Flutter's layout Engine (BoxFit.cover) 
      // rather than slow pixel-by-pixel manipulation.

      if (mounted) {
        Navigator.pop(context, image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _showHelpDialog() {
    bool dontShowAgain = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.auto_fix_high_rounded, color: AppTheme.primary),
                SizedBox(width: 12),
                Text('Pose Match'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perfectly match your pose by overlaying a reference photo from your gallery.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildHelpItem(
                  icon: Icons.photo_library_outlined,
                  title: '1. Select Photo',
                  desc: 'Tap the library icon to choose a previous session\'s photo.',
                ),
                const SizedBox(height: 16),
                _buildHelpItem(
                  icon: Icons.opacity,
                  title: '2. Adjust Opacity',
                  desc: 'Use the slider to make the reference photo transparent.',
                ),
                const SizedBox(height: 16),
                _buildHelpItem(
                  icon: Icons.camera_alt_rounded,
                  title: '3. Match & Capture',
                  desc: 'Align your body with the ghost image and take the photo.',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: dontShowAgain,
                        activeColor: AppTheme.primary,
                        onChanged: (val) {
                          setState(() {
                            dontShowAgain = val ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Don\'t show again', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (dontShowAgain) {
                    ref.read(cameraTipDismissedProvider.notifier).dismiss();
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Got it', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildControlCircle({required IconData icon, required VoidCallback onTap, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildHelpItem({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZoomToggle(double zoom) {
    if (zoom > _maxZoom && zoom != 1.0) return const SizedBox.shrink();

    final isSelected = _currentZoom.toStringAsFixed(1) == zoom.toStringAsFixed(1);

    return GestureDetector(
      onTap: () => _setZoom(zoom),
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.white : Colors.white10),
        ),
        child: Center(
          child: Text(
            '${zoom.toInt()}x',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final photosAsync = ref.watch(progressPhotosProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview & Pose Match
          Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    onTapUp: (details) => _onTapFocus(details, constraints),
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Transform.scale(
                              // Using the inverse of aspect ratio * target ratio to fill height without stretching
                              scale: 1 / (_controller!.value.aspectRatio * (9 / 16)),
                              child: CameraPreview(_controller!),
                            ),
                          ),
                        if (_referencePath != null)
                          IgnorePointer(
                            child: Opacity(
                              opacity: _overlayOpacity,
                              child: Image.file(
                                File(_referencePath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              ),
            ),
          ),

          // Main UI Overlay
          AbsorbPointer(
            absorbing: _isCapturing,
            child: SafeArea(
              child: Column(
                children: [
                  // Top Settings Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                        
                        const Text(
                          '9:16 RESOLUTION',
                          style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 2),
                        ),

                        IconButton(
                          icon: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 28),
                          onPressed: _showHelpDialog,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Zoom Toggles
                  if (_maxZoom > 1.0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildZoomToggle(1.0),
                          _buildZoomToggle(3.0),
                          _buildZoomToggle(5.0),
                          _buildZoomToggle(10.0),
                        ],
                      ),
                    ),

                  // Controls Area
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Opacity Slider (only when ghost is active)
                        if (_referencePath != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              children: [
                                const Icon(Icons.opacity, color: Colors.white70, size: 18),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppTheme.primary,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                      trackHeight: 2,
                                    ),
                                    child: Slider(
                                      value: _overlayOpacity,
                                      onChanged: (val) => setState(() => _overlayOpacity = val),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(_overlayOpacity * 100).toInt()}%',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        
                        // Main Controls Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Gallery Icon / Reference Toggle
                            _buildControlCircle(
                              icon: _referencePath != null ? Icons.photo_library_rounded : Icons.photo_library_outlined,
                              color: _referencePath != null ? AppTheme.primary : Colors.white,
                              onTap: () => setState(() => _showReferencePicker = !_showReferencePicker),
                            ),

                            // Shutter Button
                            GestureDetector(
                              onTap: _takePicture,
                              child: Container(
                                height: 80,
                                width: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.camera_alt, color: Colors.black26, size: 30),
                                  ),
                                ),
                              ),
                            ),

                            // Camera Toggle (Switch Lens)
                            _buildControlCircle(
                              icon: Icons.flip_camera_ios_rounded,
                              onTap: _toggleCamera,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Horizontal Reference Picker
          if (_showReferencePicker)
            Positioned(
              bottom: 140,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                color: Colors.black87,
                child: photosAsync.when(
                  data: (photos) {
                    if (photos.isEmpty) {
                      return const Center(child: Text('No photos to use as reference', style: TextStyle(color: Colors.white70)));
                    }
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        final isSelected = _referencePath == photo.path;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _referencePath = null;
                              } else {
                                _referencePath = photo.path;
                                _showReferencePicker = false;
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : Colors.white24,
                                width: 2,
                              ),
                              image: DecorationImage(
                                image: FileImage(File(photo.path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error loading photos', style: TextStyle(color: Colors.white70))),
                ),
              ),
            ),

          // Processing Overlay on Top
          if (_isCapturing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary),
                    SizedBox(height: 16),
                    Text(
                      'PROCESSING...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 12,
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
