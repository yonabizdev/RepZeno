import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' hide context;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:archive/archive_io.dart';
import '../theme/app_theme.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/glass_app_bar.dart';
import '../database/database_helper.dart';
import '../providers/repository_providers.dart';
import '../providers/workout_provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/progress_photo_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isImporting = false;

  Future<void> _exportDatabase() async {
    if (kIsWeb) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backups are not supported on the Web version.')));
      return;
    }
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dbPath = join(docsDir.path, 'repzeno.db');
      final file = File(dbPath);
      
      if (await file.exists()) {
        final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
        final tempDir = await getTemporaryDirectory();
        
        // Create an archive containing the DB and all progress photos
        final archive = Archive();
        
        // 1. Add DB file
        final dbBytes = await file.readAsBytes();
        archive.addFile(ArchiveFile('repzeno.db', dbBytes.length, dbBytes));
        
        // 2. Add Photos directory if exists
        final photosDir = Directory(join(docsDir.path, 'progress_photos'));
        if (await photosDir.exists()) {
          final entities = await photosDir.list().toList();
          for (final entity in entities) {
            if (entity is File) {
              final bytes = await entity.readAsBytes();
              // Store as progress_photos/filename.ext in zip
              final name = join('progress_photos', basename(entity.path));
              archive.addFile(ArchiveFile(name, bytes.length, bytes));
            }
          }
        }

        final zipEncoder = ZipEncoder();
        final zipBytes = zipEncoder.encode(archive);
        
        final backupFileName = 'RepZeno_Full_Backup_$timestamp.zip';
        final tempBackupFile = File(join(tempDir.path, backupFileName));
        await tempBackupFile.writeAsBytes(zipBytes);
        
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(tempBackupFile.path, mimeType: 'application/zip')],
            text: 'RepZeno Complete Backup (History + Photos)',
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No database found to export.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importDatabase() async {
    if (kIsWeb) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backups are not supported on the Web version.')));
      return;
    }
    
    if (_isImporting) return;
    setState(() => _isImporting = true);
    
    try {
      // Clear temp files to prevent deadlocks from previous failed picks (especially from cloud providers)
      await FilePicker.platform.clearTemporaryFiles().catchError((_) => false);
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'zip'],
      );
      
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final String dbToMergePath;
        
        if (filePath.endsWith('.zip')) {
          // Handle ZIP full backup
          final bytes = await File(filePath).readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);
          final tempDir = await getTemporaryDirectory();
          final extractDir = Directory(join(tempDir.path, 'repzeno_restore_${DateTime.now().millisecondsSinceEpoch}'));
          await extractDir.create(recursive: true);

          String? extractedDbPath;
          final photosDir = Directory(join((await getApplicationDocumentsDirectory()).path, 'progress_photos'));
          if (!await photosDir.exists()) await photosDir.create(recursive: true);

          for (final file in archive) {
            final filename = file.name;
            if (file.isFile) {
              final data = file.content as List<int>;
              final outFile = File(join(extractDir.path, filename));
              await outFile.parent.create(recursive: true);
              await outFile.writeAsBytes(data);

              if (filename == 'repzeno.db') {
                extractedDbPath = outFile.path;
              } else if (filename.startsWith('progress_photos/')) {
                // Move photo to the app's progress_photos directory
                final photoName = basename(filename);
                final finalPhotoPath = join(photosDir.path, photoName);
                await outFile.copy(finalPhotoPath);
              }
            }
          }

          if (extractedDbPath == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid backup: repzeno.db not found in ZIP.')),
              );
            }
            return;
          }
          dbToMergePath = extractedDbPath;
        } else if (filePath.endsWith('.db')) {
          dbToMergePath = filePath;
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid file type. Please select a .zip or .db backup file.')));
          return;
        }

        // Validate structure by attempting to open it
        try {
          final testDb = await openDatabase(dbToMergePath, readOnly: true);
          final tables = await testDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
          final tableNames = tables.map((e) => e['name'] as String).toList();
          await testDb.close();
          
          if (!tableNames.contains('exercises') || !tableNames.contains('workouts')) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid database structure. Not a RepZeno backup file.')));
             return;
          }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corrupt or invalid database file.')));
          return;
        }

        // Merge the incoming database with the current one instead of overwriting
        await DatabaseHelper.instance.mergeDatabase(dbToMergePath);
        
        // Force Riverpod to dump cached memory and pull fresh from the new DB
        ref.invalidate(workoutRepositoryProvider);
        ref.invalidate(exerciseRepositoryProvider);
        ref.invalidate(profileRepositoryProvider);
        ref.invalidate(allWorkoutsProvider);
        ref.invalidate(workoutByDateProvider);
        ref.invalidate(muscleGroupsProvider);
        ref.invalidate(userProfileProvider);
        ref.invalidate(weightLogsProvider);
        ref.invalidate(progressPhotosProvider);
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text('Import Successful'),
              content: const Text('Database restored! Your data has been instantly refreshed.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/');
                  },
                  child: const Text('OK', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _deleteAllData() async {
    if (kIsWeb) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not supported on Web.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text('This will permanently erase all your workout history, progress photos, profile habits, and weight logs. This action cannot be undone.'),
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
                    child: const Text('Delete All'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;
    
    // Safely close the active connection first
    await DatabaseHelper.instance.closeAndReset();
    
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docsDir.path, 'repzeno.db');
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
      
      // Force Riverpod to clear UI caches
      ref.invalidate(workoutRepositoryProvider);
      ref.invalidate(exerciseRepositoryProvider);
      ref.invalidate(profileRepositoryProvider);
      ref.invalidate(allWorkoutsProvider);
      ref.invalidate(workoutByDateProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(weightLogsProvider);
      ref.invalidate(progressPhotosProvider);
      
      // Also delete the progress_photos directory if it exists
      final photosDir = Directory(join(docsDir.path, 'progress_photos'));
      if (await photosDir.exists()) {
        await photosDir.delete(recursive: true);
      }

      if (mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topContentInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Settings')),
      body: AppBackdrop(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topContentInset, 16, 24),
          children: [
            _SettingsSection(
              title: 'Preferences',
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final isAscending = ref.watch(sortSetsAscendingProvider);
                    return ListTile(
                      leading: const Icon(Icons.sort_rounded, color: AppTheme.primary),
                      title: const Text('Set Sort Order'),
                      subtitle: Text(isAscending ? 'Oldest sets first' : 'Newest sets first'),
                      onTap: () => ref.read(sortSetsAscendingProvider.notifier).toggle(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Data & Backups',
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded, color: AppTheme.primary),
                  title: const Text('Export Backup'),
                  subtitle: const Text('Save your workout history, profile, weight logs, and transformation photos.'),
                  onTap: () => _exportDatabase(),
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: AppTheme.primary),
                  title: const Text('Import Backup'),
                  subtitle: const Text('Restore workouts, profile details, weight logs, and photos.'),
                  onTap: () => _importDatabase(),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.primary),
                  title: const Text('Privacy & Data'),
                  subtitle: const Text('Learn how RepZeno protects you.'),
                  onTap: () => context.push('/privacy'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Danger Zone',
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: const Text('Delete All Data', style: TextStyle(color: Colors.redAccent)),
                  subtitle: const Text('Permanently wipe workouts, exercises, profile, weight logs, and transformation gallery.'),
                  onTap: _deleteAllData,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}
