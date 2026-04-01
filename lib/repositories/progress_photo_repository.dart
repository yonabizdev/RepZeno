import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/progress_photo.dart';

class ProgressPhotoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<ProgressPhoto>> getPhotos() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'progress_photos',
      orderBy: 'date DESC, createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return ProgressPhoto.fromMap(maps[i]);
    });
  }

  Future<int> addPhoto(ProgressPhoto photo) async {
    final db = await _dbHelper.database;
    return await db.insert('progress_photos', photo.toMap());
  }

  Future<int> deletePhoto(int id, String filePath) async {
    final db = await _dbHelper.database;
    
    // Also delete the physical file
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Log error or ignore if file already missing
    }

    return await db.delete(
      'progress_photos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> saveImageLocally(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(directory.path, 'progress_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final String fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(imageFile.path)}';
    final String localPath = p.join(photosDir.path, fileName);
    
    await imageFile.copy(localPath);
    return localPath;
  }

  Future<int> updatePhotoDate(int id, String date) async {
    final db = await _dbHelper.database;
    return await db.update(
      'progress_photos',
      {'date': date},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
