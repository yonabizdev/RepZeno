import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../models/progress_photo.dart';
import '../providers/profile_provider.dart';
import '../providers/progress_photo_provider.dart';
import '../theme/app_theme.dart';

class PhotoViewScreen extends ConsumerStatefulWidget {
  final List<ProgressPhoto> photos;
  final int initialIndex;

  const PhotoViewScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  ConsumerState<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends ConsumerState<PhotoViewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<ProgressPhoto> _mutablePhotos;
  bool _showWeight = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _mutablePhotos = List.from(widget.photos);
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  Future<void> _deleteCurrentPhoto() async {
    final photo = _mutablePhotos[_currentIndex];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text('Are you sure you want to delete this photo? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Delete from database and file system
      await ref.read(progressPhotosProvider.notifier).deletePhoto(photo);
      
      setState(() {
        _mutablePhotos.removeAt(_currentIndex);
        if (_mutablePhotos.isEmpty) {
          context.pop(); // Go back if empty
        } else {
          // Adjust index if we deleted the last item
          if (_currentIndex >= _mutablePhotos.length) {
            _currentIndex = _mutablePhotos.length - 1;
            // The PageView should automatically update, but we can jump if needed.
            // Using a post frame callback to let PageView rebuild with new item count first.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                _pageController.jumpToPage(_currentIndex);
              }
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weightLogsAsync = ref.watch(weightLogsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black45,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM dd, yyyy').format(DateTime.parse(_mutablePhotos[_currentIndex].date)),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_currentIndex + 1} of ${_mutablePhotos.length}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: _deleteCurrentPhoto,
            tooltip: 'Delete Photo',
          ),
          IconButton(
            icon: Icon(
              _showWeight ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _showWeight = !_showWeight),
            tooltip: 'Toggle Weight Overlay',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _mutablePhotos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final photo = _mutablePhotos[index];
          
          // Find matching weight for this date
          double? weight;
          if (weightLogsAsync.hasValue) {
            final match = weightLogsAsync.value!
                .where((l) => l.date.startsWith(photo.date))
                .firstOrNull;
            if (match != null) {
              weight = match.weight;
            }
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: Hero(
                    tag: photo.path,
                    child: Image.file(
                      File(photo.path),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
              if (_showWeight && weight != null)
                Positioned(
                  bottom: MediaQuery.paddingOf(context).bottom + 40,
                  left: 24,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monitor_weight_rounded, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$weight kg',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
