import '../database/database_helper.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';

class WorkoutRepository {
  final dbHelper = DatabaseHelper.instance;

  // Returns the workout only if it already contains at least one exercise.
  // This prevents "empty workouts" from showing up in the UI and dashboard stats.
  Future<Workout?> getWorkoutByDate(String date) async {
    final db = await dbHelper.database;
    final maps = await db.rawQuery(
      '''
      SELECT w.*
      FROM workouts w
      WHERE w.date = ?
        AND EXISTS (
          SELECT 1 FROM workout_exercises we WHERE we.workoutId = w.id
        )
      LIMIT 1
      ''',
      [date],
    );
    if (maps.isNotEmpty) {
      return Workout.fromMap(maps.first);
    }
    return null;
  }

  Future<Workout?> getWorkoutRecordByDate(String date) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'workouts',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Workout.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Workout>> getAllWorkouts() async {
    final db = await dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT w.*
      FROM workouts w
      WHERE EXISTS (
        SELECT 1
        FROM workout_exercises we
        JOIN workout_sets ws ON ws.workoutExerciseId = we.id
        WHERE we.workoutId = w.id
      )
      ORDER BY w.date DESC, w.id DESC
      ''');
    return maps.map((map) => Workout.fromMap(map)).toList();
  }

  Future<Workout> createWorkout(String date) async {
    final db = await dbHelper.database;
    final id = await db.insert('workouts', {'date': date});
    return Workout(id: id, date: date);
  }

  Future<Workout> getOrCreateWorkout(String date) async {
    final existing = await getWorkoutRecordByDate(date);
    if (existing != null) {
      return existing;
    }
    return createWorkout(date);
  }

  Future<WorkoutExercise> addExerciseToWorkout(
    int workoutId,
    int exerciseId,
  ) async {
    final db = await dbHelper.database;
    final id = await db.insert('workout_exercises', {
      'workoutId': workoutId,
      'exerciseId': exerciseId,
    });
    return WorkoutExercise(
      id: id,
      workoutId: workoutId,
      exerciseId: exerciseId,
    );
  }

  Future<List<WorkoutExercise>> getExercisesForWorkout(int workoutId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'workout_exercises',
      where: 'workoutId = ?',
      whereArgs: [workoutId],
      orderBy: 'id DESC',
    );
    return maps.map((map) => WorkoutExercise.fromMap(map)).toList();
  }

  Future<void> removeExerciseFromWorkout(int workoutExerciseId) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      final workoutExercise = await txn.query(
        'workout_exercises',
        columns: ['workoutId'],
        where: 'id = ?',
        whereArgs: [workoutExerciseId],
        limit: 1,
      );
      final workoutId =
          workoutExercise.isEmpty
              ? null
              : (workoutExercise.first['workoutId'] as int);

      await txn.delete(
        'workout_sets',
        where: 'workoutExerciseId = ?',
        whereArgs: [workoutExerciseId],
      );
      await txn.delete(
        'workout_exercises',
        where: 'id = ?',
        whereArgs: [workoutExerciseId],
      );

      if (workoutId != null) {
        final remaining = await txn.rawQuery(
          'SELECT COUNT(*) as c FROM workout_exercises WHERE workoutId = ?',
          [workoutId],
        );
        final count = (remaining.first['c'] as num?)?.toInt() ?? 0;
        if (count == 0) {
          await txn.delete('workouts', where: 'id = ?', whereArgs: [workoutId]);
        }
      }
    });
  }

  Future<List<WorkoutSet>> getSetsForWorkoutExercise(
    int workoutExerciseId,
  ) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'workout_sets',
      where: 'workoutExerciseId = ?',
      whereArgs: [workoutExerciseId],
      orderBy: 'createdAt ASC, id ASC',
    );
    return maps.map((map) => WorkoutSet.fromMap(map)).toList();
  }

  Future<WorkoutSet> addSet(
    int workoutExerciseId,
    double weight,
    int reps, {
    String? createdAt,
  }) async {
    final db = await dbHelper.database;
    final timestamp = createdAt ?? DateTime.now().toIso8601String();
    final id = await db.insert('workout_sets', {
      'workoutExerciseId': workoutExerciseId,
      'weight': weight,
      'reps': reps,
      'createdAt': timestamp,
    });
    return WorkoutSet(
      id: id,
      workoutExerciseId: workoutExerciseId,
      weight: weight,
      reps: reps,
      createdAt: timestamp,
    );
  }

  Future<WorkoutSet> addDurationSet(
    int workoutExerciseId,
    int durationSeconds, {
    String? createdAt,
  }) async {
    final db = await dbHelper.database;
    final timestamp = createdAt ?? DateTime.now().toIso8601String();
    final id = await db.insert('workout_sets', {
      'workoutExerciseId': workoutExerciseId,
      'durationSeconds': durationSeconds,
      'createdAt': timestamp,
    });
    return WorkoutSet(
      id: id,
      workoutExerciseId: workoutExerciseId,
      durationSeconds: durationSeconds,
      createdAt: timestamp,
    );
  }

  Future<WorkoutSet> addRepsSet(
    int workoutExerciseId,
    int reps, {
    String? createdAt,
  }) async {
    final db = await dbHelper.database;
    final timestamp = createdAt ?? DateTime.now().toIso8601String();
    final id = await db.insert('workout_sets', {
      'workoutExerciseId': workoutExerciseId,
      'reps': reps,
      'createdAt': timestamp,
    });
    return WorkoutSet(
      id: id,
      workoutExerciseId: workoutExerciseId,
      reps: reps,
      createdAt: timestamp,
    );
  }

  Future<void> deleteSet(int setId) async {
    final db = await dbHelper.database;
    await db.delete('workout_sets', where: 'id = ?', whereArgs: [setId]);
  }

  Future<void> updateSet(int setId, double weight, int reps) async {
    final db = await dbHelper.database;
    await db.update(
      'workout_sets',
      {'weight': weight, 'reps': reps, 'durationSeconds': null},
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  Future<void> updateDurationSet(int setId, int durationSeconds) async {
    final db = await dbHelper.database;
    await db.update(
      'workout_sets',
      {'durationSeconds': durationSeconds, 'weight': null, 'reps': null},
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  Future<void> updateRepsSet(int setId, int reps) async {
    final db = await dbHelper.database;
    await db.update(
      'workout_sets',
      {'reps': reps, 'weight': null, 'durationSeconds': null},
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  Future<List<Map<String, dynamic>>> getMuscleHistory(int muscleGroupId) async {
    final db = await dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        w.date as workout_date, 
        e.name as exercise_name, 
        e.trackingType as tracking_type,
        s.weight as set_weight, 
        s.reps as set_reps,
        s.durationSeconds as set_duration_seconds
      FROM workouts w
      JOIN workout_exercises we ON w.id = we.workoutId
      JOIN exercises e ON we.exerciseId = e.id
      JOIN workout_sets s ON we.id = s.workoutExerciseId
      WHERE e.muscleGroupId = ?
      ORDER BY w.date DESC, we.id DESC, s.id ASC
    ''',
      [muscleGroupId],
    );
    return results;
  }

  Future<List<Map<String, dynamic>>> getExerciseHistory(int exerciseId) async {
    final db = await dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        w.date as workout_date, 
        e.name as exercise_name, 
        e.trackingType as tracking_type,
        s.weight as set_weight, 
        s.reps as set_reps,
        s.durationSeconds as set_duration_seconds
      FROM workouts w
      JOIN workout_exercises we ON w.id = we.workoutId
      JOIN exercises e ON we.exerciseId = e.id
      JOIN workout_sets s ON we.id = s.workoutExerciseId
      WHERE e.id = ?
      ORDER BY w.date DESC, we.id DESC, s.id ASC
    ''',
      [exerciseId],
    );
    return results;
  }

  Future<Map<String, int>> getWorkoutStats(int workoutId) async {
    final db = await dbHelper.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        (SELECT COUNT(*) FROM workout_exercises WHERE workoutId = ?) as exerciseCount,
        (SELECT COUNT(*) FROM workout_sets ws 
         JOIN workout_exercises we ON ws.workoutExerciseId = we.id 
         WHERE we.workoutId = ?) as setCount
      ''',
      [workoutId, workoutId],
    );
    if (results.isNotEmpty) {
      final row = results.first;
      return {
        'exerciseCount': (row['exerciseCount'] as num?)?.toInt() ?? 0,
        'setCount': (row['setCount'] as num?)?.toInt() ?? 0,
      };
    }
    return {'exerciseCount': 0, 'setCount': 0};
  }
}
