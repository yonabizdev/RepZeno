import '../database/database_helper.dart';
import '../models/muscle_group.dart';
import '../models/exercise.dart';
import '../models/exercise_tracking_type.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DuplicateExerciseException implements Exception {
  final String message;

  const DuplicateExerciseException(this.message);

  @override
  String toString() => message;
}

class ExerciseInUseException implements Exception {
  final String message;

  const ExerciseInUseException(this.message);

  @override
  String toString() => message;
}

class ExerciseRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<List<MuscleGroup>> getMuscleGroups() async {
    final db = await dbHelper.database;
    final maps = await db.query('muscle_groups', orderBy: 'name ASC');
    return maps.map((map) => MuscleGroup.fromMap(map)).toList();
  }

  Future<List<Exercise>> getExercisesByMuscleGroup(int muscleGroupId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'exercises',
      where: 'muscleGroupId = ? AND isArchived = 0',
      whereArgs: [muscleGroupId],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Exercise.fromMap(map)).toList();
  }

  Future<List<Exercise>> getAllExercises({bool includeArchived = true}) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'exercises',
      where: includeArchived ? null : 'isArchived = 0',
      orderBy: 'name ASC',
    );
    return maps.map((map) => Exercise.fromMap(map)).toList();
  }

  Future<List<Exercise>> getLibraryExercises() async {
    return getAllExercises(includeArchived: false);
  }

  Future<List<Exercise>> getCustomExercises() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'exercises',
      where: 'isCustom = ? AND isArchived = 0',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Exercise.fromMap(map)).toList();
  }

  Future<Exercise> addExercise(Exercise exercise) async {
    final db = await dbHelper.database;
    final normalizedName = _normalizeExerciseName(exercise.name);

    final activeDuplicate = await _findExerciseByName(
      db,
      name: normalizedName,
      muscleGroupId: exercise.muscleGroupId,
      isArchived: false,
    );

    if (activeDuplicate != null) {
      throw DuplicateExerciseException(
        'An exercise named "$normalizedName" already exists under this muscle group.',
      );
    }

    final archivedDuplicate = await _findExerciseByName(
      db,
      name: normalizedName,
      muscleGroupId: exercise.muscleGroupId,
      isArchived: true,
    );

    if (archivedDuplicate != null) {
      final archivedId = archivedDuplicate['id'] as int;
      final archivedIsCustom =
          (archivedDuplicate['isCustom'] as int? ?? 0) == 1;
      final archivedTrackingType = ExerciseTrackingTypeDb.fromDb(
        archivedDuplicate['trackingType'],
      );

      await db.update(
        'exercises',
        {'name': normalizedName, 'isArchived': 0},
        where: 'id = ?',
        whereArgs: [archivedId],
      );

      return Exercise(
        id: archivedId,
        name: normalizedName,
        muscleGroupId: exercise.muscleGroupId,
        isCustom: archivedIsCustom,
        trackingType: archivedTrackingType,
      );
    }

    final id = await db.insert(
      'exercises',
      exercise.copyWith(name: normalizedName).toMap(),
    );
    return exercise.copyWith(id: id, name: normalizedName);
  }

  Future<void> updateExercise(Exercise exercise) async {
    final db = await dbHelper.database;
    final normalizedName = _normalizeExerciseName(exercise.name);
    final activeDuplicate = await _findExerciseByName(
      db,
      name: normalizedName,
      muscleGroupId: exercise.muscleGroupId,
      excludeExerciseId: exercise.id,
      isArchived: false,
    );

    if (activeDuplicate != null) {
      throw DuplicateExerciseException(
        'An exercise named "$normalizedName" already exists under this muscle group.',
      );
    }

    final usageCount = await getExerciseUsageCount(exercise.id!);
    if (usageCount > 0) {
      final existing = await db.query(
        'exercises',
        columns: ['muscleGroupId', 'trackingType'],
        where: 'id = ? AND isArchived = 0',
        whereArgs: [exercise.id],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final currentMuscleGroupId = existing.first['muscleGroupId'] as int;
        final currentTrackingType = ExerciseTrackingTypeDb.fromDb(
          existing.first['trackingType'],
        );

        if (exercise.muscleGroupId != currentMuscleGroupId) {
          throw const ExerciseInUseException(
            'Muscle group cannot be changed once the exercise has workout history.',
          );
        }

        if (exercise.trackingType != currentTrackingType) {
          throw const ExerciseInUseException(
            'Logging style cannot be changed once the exercise has workout history.',
          );
        }
      }
    }

    await db.update(
      'exercises',
      exercise.copyWith(name: normalizedName).toMap(),
      where: 'id = ? AND isArchived = 0',
      whereArgs: [exercise.id],
    );
  }

  Future<void> deleteExercise(int exerciseId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'exercises',
      columns: ['seedKey', 'isCustom'],
      where: 'id = ?',
      whereArgs: [exerciseId],
      limit: 1,
    );

    if (maps.isEmpty) {
      return;
    }

    final usage = await getExerciseUsageCount(exerciseId);

    final seedKey = maps.first['seedKey'] as String?;
    final isCustom = (maps.first['isCustom'] as int? ?? 0) == 1;

    if (usage > 0) {
      throw const ExerciseInUseException(
        'Exercise cannot be deleted once it has workout history.',
      );
    }

    if (seedKey != null || !isCustom) {
      await db.update(
        'exercises',
        {'isArchived': 1},
        where: 'id = ?',
        whereArgs: [exerciseId],
      );
      return;
    }

    await db.delete('exercises', where: 'id = ?', whereArgs: [exerciseId]);
  }

  Future<int> getExerciseUsageCount(int exerciseId) async {
    final db = await dbHelper.database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM workout_exercises WHERE exerciseId = ?',
            [exerciseId],
          ),
        ) ??
        0;
  }

  Future<Map<String, Object?>?> _findExerciseByName(
    Database db, {
    required String name,
    required int muscleGroupId,
    required bool isArchived,
    int? excludeExerciseId,
  }) async {
    final whereBuffer = StringBuffer(
      'muscleGroupId = ? AND isArchived = ? AND LOWER(TRIM(name)) = LOWER(TRIM(?))',
    );
    final whereArgs = <Object?>[muscleGroupId, isArchived ? 1 : 0, name];

    if (excludeExerciseId != null) {
      whereBuffer.write(' AND id != ?');
      whereArgs.add(excludeExerciseId);
    }

    final maps = await db.query(
      'exercises',
      columns: ['id', 'isCustom', 'trackingType'],
      where: whereBuffer.toString(),
      whereArgs: whereArgs,
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return maps.first;
  }

  String _normalizeExerciseName(String name) {
    final collapsed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) {
      return collapsed;
    }

    final buffer = StringBuffer();
    var capitalizeNext = true;

    for (final codeUnit in collapsed.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      final isAsciiLetter = RegExp(r'[A-Za-z]').hasMatch(char);
      final isDigit = RegExp(r'\d').hasMatch(char);

      if (isAsciiLetter) {
        buffer.write(capitalizeNext ? char.toUpperCase() : char.toLowerCase());
        capitalizeNext = false;
        continue;
      }

      buffer.write(char);

      if (_isWordBoundary(char)) {
        capitalizeNext = true;
      } else if (isDigit) {
        capitalizeNext = false;
      }
    }

    return buffer.toString();
  }

  bool _isWordBoundary(String char) {
    return char == ' ' ||
        char == '-' ||
        char == '/' ||
        char == '&' ||
        char == '+' ||
        char == '(';
  }
}
