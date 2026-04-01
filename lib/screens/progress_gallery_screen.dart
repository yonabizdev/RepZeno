import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/progress_photo.dart';
import '../providers/progress_photo_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/glass_app_bar.dart';
import '../providers/settings_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ProgressGalleryScreen extends ConsumerStatefulWidget {
  const ProgressGalleryScreen({super.key});

  @override
  ConsumerState<ProgressGalleryScreen> createState() => _ProgressGalleryScreenState();
}

class _ProgressGalleryScreenState extends ConsumerState<ProgressGalleryScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Industry Standard: Explicitly check and request permissions for privacy & safety
      PermissionStatus status;
      if (source == ImageSource.camera) {
        status = await Permission.camera.request();
      } else {
        // Permission.photos handles Photo Library on iOS and READ_MEDIA_IMAGES on Android 13+
        status = await Permission.photos.request();
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${source == ImageSource.camera ? 'Camera' : 'Gallery'} access is permanently denied. Please enable it in settings.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
                textColor: AppTheme.primary,
              ),
              backgroundColor: AppTheme.surfaceElevated,
            ),
          );
        }
        return;
      }

      if (!status.isGranted && !status.isLimited) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${source == ImageSource.camera ? 'Camera' : 'Gallery'} access is required to add photos.')),
          );
        }
        return;
      }

      if (source == ImageSource.gallery) {
        final List<XFile> images = await _picker.pickMultiImage(
          maxWidth: 1080,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (images.length > 15) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Maximum 15 photos allowed per selection.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppTheme.surfaceElevated,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        if (images.isNotEmpty && mounted) {
          final repository = ref.read(progressPhotoRepositoryProvider);
          final DateFormat format = DateFormat('yyyy-MM-dd');
          final String today = format.format(DateTime.now());
          
          for (final image in images) {
            final localPath = await repository.saveImageLocally(File(image.path));
            final newPhoto = ProgressPhoto(
              path: localPath,
              date: today,
              createdAt: DateTime.now().toIso8601String(),
            );
            await ref.read(progressPhotosProvider.notifier).addPhoto(newPhoto);
          }
        }
      } else {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 1080,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null && mounted) {
          final repository = ref.read(progressPhotoRepositoryProvider);
          final localPath = await repository.saveImageLocally(File(image.path));
          
          final newPhoto = ProgressPhoto(
            path: localPath,
            date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
            createdAt: DateTime.now().toIso8601String(),
          );
          
          await ref.read(progressPhotosProvider.notifier).addPhoto(newPhoto);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Add Photo to Tracker',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
                title: const Text('Choose from library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedPhotos() async {
    final photos = ref.read(progressPhotosProvider).value ?? [];
    final toDelete = photos.where((p) => _selectedIds.contains(p.id)).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photos?'),
        content: Text('Are you sure you want to delete ${toDelete.length} photos? This cannot be undone.'),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed && mounted) {
      final notifier = ref.read(progressPhotosProvider.notifier);
      for (final photo in toDelete) {
        await notifier.deletePhoto(photo);
      }
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
    }
  }

  void _startComparison() {
    if (_selectedIds.length != 2) return;
    
    final photos = ref.read(progressPhotosProvider).value ?? [];
    final selectedPhotos = photos.where((p) => _selectedIds.contains(p.id)).toList();
    
    // Sort by date so older is "Before" and newer is "After"
    selectedPhotos.sort((a, b) => a.date.compareTo(b.date));
    
    final photoA = selectedPhotos[0];
    final photoB = selectedPhotos[1];
    
    context.push('/progress/compare?pathA=${Uri.encodeComponent(photoA.path)}&dateA=${photoA.date}&pathB=${Uri.encodeComponent(photoB.path)}&dateB=${photoB.date}');
    
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _editPhotoDate() async {
    if (_selectedIds.isEmpty) return;
    
    final photos = ref.read(progressPhotosProvider).value ?? [];
    final firstPhoto = photos.firstWhere((p) => _selectedIds.contains(p.id));
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(firstPhoto.date),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceElevated,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final notifier = ref.read(progressPhotosProvider.notifier);
      final newDateStr = DateFormat('yyyy-MM-dd').format(picked);
      
      final toUpdate = photos.where((p) => _selectedIds.contains(p.id)).toList();
      for (final photo in toUpdate) {
        await notifier.updatePhotoDate(photo, newDateStr);
      }
      
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo dates updated successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photosAsync = ref.watch(progressPhotosProvider);
    final topContentInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(_isSelectionMode ? '${_selectedIds.length} Selected' : 'My Progress'),
        leading: _isSelectionMode 
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              }),
            )
          : null,
        actions: _isSelectionMode 
          ? [
              if (_selectedIds.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.calendar_month_rounded, size: 28),
                  onPressed: _editPhotoDate,
                  tooltip: 'Change Date',
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 28),
                onPressed: _deleteSelectedPhotos,
                tooltip: 'Delete',
              ),
            ]
          : null,
      ),
      body: AppBackdrop(
        child: photosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading photos')),
          data: (photos) {
            if (photos.isEmpty) {
              return _buildEmptyState(topContentInset);
            }
            return _buildGroupedGallery(photos, topContentInset);
          },
        ),
      ),
      floatingActionButton: _buildFAB(photosAsync),
    );
  }

  Widget? _buildFAB(AsyncValue<List<ProgressPhoto>> photosAsync) {
    if (_isSelectionMode) {
      if (_selectedIds.length == 2) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [AppTheme.primary, Color(0xFFFF6D00)], // Vibrant orange gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: _startComparison,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Compare Now',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return null;
    }

    if (photosAsync.value?.isEmpty ?? true) return null;

    return FloatingActionButton.extended(
      onPressed: () => _showImageSourceActionSheet(context),
      label: const Text('Add Photo', style: TextStyle(fontWeight: FontWeight.bold)),
      icon: const Icon(Icons.add_a_photo_rounded),
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
    );
  }

  Widget _buildEmptyState(double topContentInset) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topContentInset, 16, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 60, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text(
              'No Transformation Photos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track your progress visually. Your photos are stored securely and privately only on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showImageSourceActionSheet(context),
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Start My Journey'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipHeader() {
    final dismissed = ref.watch(transformationTipDismissedProvider);
    if (dismissed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Tip: Long-press to select two photos and compare your transformation.',
                style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
              onPressed: () => ref.read(transformationTipDismissedProvider.notifier).dismiss(),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Dismiss Tip',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedGallery(List<ProgressPhoto> photos, double topContentInset) {
    // Group photos by date
    final groupedPhotos = <String, List<ProgressPhoto>>{};
    // Sort descending (newest first)
    final sortedPhotos = List<ProgressPhoto>.from(photos)..sort((a, b) => b.date.compareTo(a.date));
    for (final p in sortedPhotos) {
      groupedPhotos.putIfAbsent(p.date, () => []).add(p);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: topContentInset),
        ),
        SliverToBoxAdapter(
          child: _buildTipHeader(),
        ),
        ...groupedPhotos.entries.map((entry) {
          return SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  DateFormat('MMMM dd, yyyy').format(DateTime.parse(entry.key)),
                  style: const TextStyle(
                    fontSize: 17, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white
                  ),
                ),
              ),
              GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: entry.value.length,
                itemBuilder: (context, index) {
                  final photo = entry.value[index];
                  final isSelected = _selectedIds.contains(photo.id);

                  return GestureDetector(
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedIds.add(photo.id!);
                        });
                      }
                    },
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(photo.id!);
                      } else {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedIds.add(photo.id!);
                        });
                      }
                    },
                    child: _PhotoCard(photo: photo, isSelected: isSelected, isSelectionMode: _isSelectionMode),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final ProgressPhoto photo;
  final bool isSelected;
  final bool isSelectionMode;

  const _PhotoCard({
    required this.photo, 
    required this.isSelected,
    required this.isSelectionMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(photo.path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppTheme.surfaceMuted,
              child: const Icon(Icons.broken_image_rounded, color: AppTheme.textMuted),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Text(
                DateFormat('MMM dd, yyyy').format(DateTime.parse(photo.date)),
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.outline,
                  width: isSelected ? 3 : 1,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
            ),
          ),
          if (isSelectionMode)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.black26,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isSelected ? Icons.check : null,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
