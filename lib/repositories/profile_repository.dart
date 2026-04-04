import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database/database_helper.dart';
import '../models/user_profile.dart';
import '../models/weight_log.dart';

class ProfileRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<UserProfile?> getUserProfile() async {
    final db = await _dbHelper.database;
    final result = await db.query('user_profile', limit: 1);
    if (result.isNotEmpty) {
      return UserProfile.fromMap(result.first);
    }
    return null;
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await _dbHelper.database;
    final map = profile.toMap();
    map.remove('id'); // Auto-increment

    final result = await db.query('user_profile', limit: 1);
    if (result.isNotEmpty) {
      final id = result.first['id'] as int;
      await db.update('user_profile', map, where: 'id = ?', whereArgs: [id]);
    } else {
      await db.insert('user_profile', map);
    }
  }

  Future<List<WeightLog>> getWeightLogs() async {
    final db = await _dbHelper.database;
    final result = await db.query('weight_logs', orderBy: 'date DESC, createdAt DESC');
    return result.map((map) => WeightLog.fromMap(map)).toList();
  }

  Future<void> addWeightLog(WeightLog log) async {
    final db = await _dbHelper.database;
    final map = log.toMap();
    map.remove('id');
    await db.insert('weight_logs', map);
  }

  Future<void> updateWeightLog(WeightLog log) async {
    final db = await _dbHelper.database;
    final map = log.toMap();
    map.remove('id');
    await db.update('weight_logs', map, where: 'id = ?', whereArgs: [log.id]);
  }

  Future<void> deleteWeightLog(int id) async {
    final db = await _dbHelper.database;
    await db.delete('weight_logs', where: 'id = ?', whereArgs: [id]);
  }

  Future<WeightLog?> getWeightLogByDate(String date) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'weight_logs',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return WeightLog.fromMap(result.first);
    }
    return null;
  }
}
