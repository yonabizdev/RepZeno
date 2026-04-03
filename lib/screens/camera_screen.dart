import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/progress_photo_provider.dart';
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
  
  String? _referencePath;
  double _overlayOpacity = 0.3;
  bool _showReferencePicker = false;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      _controller = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller?.initialize();
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
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile image = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, image);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
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

  Widget _buildTipHeader() {
    return const SizedBox.shrink();
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
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: Stack(
                children: [
                  CameraPreview(_controller!),
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
          ),

          // UI Overlays
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 30),
                  onPressed: _showHelpDialog,
                ),
              ],
            ),
          ),

          // Quick Tip Header
          _buildTipHeader(),

          // Controls Area
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
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
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Row(
                        children: [
                          const Icon(Icons.opacity, color: Colors.white70, size: 20),
                          Expanded(
                            child: Slider(
                              value: _overlayOpacity,
                              onChanged: (val) => setState(() => _overlayOpacity = val),
                              activeColor: AppTheme.primary,
                              inactiveColor: Colors.white24,
                            ),
                          ),
                          Text(
                            '${(_overlayOpacity * 100).toInt()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Reference Picker Toggle
                      IconButton(
                        icon: Icon(
                          _referencePath == null ? Icons.photo_library_outlined : Icons.photo_library,
                          color: _referencePath == null ? Colors.white : AppTheme.primary,
                          size: 32,
                        ),
                        onPressed: () => setState(() => _showReferencePicker = !_showReferencePicker),
                      ),

                      // Capture Button
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),

                      // Camera Toggle (Switch Lens)
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 32),
                        onPressed: _toggleCamera,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
        ],
      ),
    );
  }
}
