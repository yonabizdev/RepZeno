import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const _dbVersion = 9;
  static const _storageProtectionChannel = MethodChannel(
    'com.repzeno.repzeno/storage',
  );
  static const List<String> _defaultMuscleGroups = [
    'Chest',
    'Back',
    'Biceps',
    'Triceps',
    'Shoulders',
    'Legs',
    'Abs',
    'Cardio',
  ];
  static const Map<String, List<_DefaultExerciseSeed>> _defaultExercises = {
    'Chest': [
      _DefaultExerciseSeed('chest_bench_press', 'Bench Press'),
      _DefaultExerciseSeed('chest_incline_bench_press', 'Incline Bench Press'),
      _DefaultExerciseSeed('chest_decline_bench_press', 'Decline Bench Press'),
      _DefaultExerciseSeed(
        'chest_dumbbell_bench_press',
        'Dumbbell Bench Press',
      ),
      _DefaultExerciseSeed('chest_dumbbell_fly', 'Dumbbell Fly'),
      _DefaultExerciseSeed('chest_cable_crossover', 'Cable Crossover'),
      _DefaultExerciseSeed('chest_push_ups', 'Push Ups', trackingType: 'reps'),
    ],
    'Back': [
      _DefaultExerciseSeed('back_pull_up', 'Pull Up', trackingType: 'reps'),
      _DefaultExerciseSeed('back_lat_pulldown', 'Lat Pulldown'),
      _DefaultExerciseSeed('back_barbell_row', 'Barbell Row'),
      _DefaultExerciseSeed('back_seated_cable_row', 'Seated Cable Row'),
      _DefaultExerciseSeed('back_deadlift', 'Deadlift'),
      _DefaultExerciseSeed('back_one_arm_dumbbell_row', 'One-Arm Dumbbell Row'),
    ],
    'Biceps': [
      _DefaultExerciseSeed('biceps_barbell_curl', 'Barbell Curl'),
      _DefaultExerciseSeed('biceps_dumbbell_curl', 'Dumbbell Curl'),
      _DefaultExerciseSeed('biceps_hammer_curl', 'Hammer Curl'),
      _DefaultExerciseSeed('biceps_preacher_curl', 'Preacher Curl'),
      _DefaultExerciseSeed('biceps_cable_curl', 'Cable Curl'),
      _DefaultExerciseSeed('biceps_concentration_curl', 'Concentration Curl'),
    ],
    'Triceps': [
      _DefaultExerciseSeed('triceps_pushdown', 'Triceps Pushdown'),
      _DefaultExerciseSeed(
        'triceps_overhead_extension',
        'Overhead Triceps Extension',
      ),
      _DefaultExerciseSeed('triceps_skull_crusher', 'Skull Crusher'),
      _DefaultExerciseSeed(
        'triceps_close_grip_bench_press',
        'Close-Grip Bench Press',
      ),
      _DefaultExerciseSeed(
        'triceps_bench_dips',
        'Bench Dips',
        trackingType: 'reps',
      ),
      _DefaultExerciseSeed('triceps_kickback', 'Triceps Kickback'),
    ],
    'Shoulders': [
      _DefaultExerciseSeed('shoulders_overhead_press', 'Overhead Press'),
      _DefaultExerciseSeed(
        'shoulders_dumbbell_shoulder_press',
        'Dumbbell Shoulder Press',
      ),
      _DefaultExerciseSeed('shoulders_arnold_press', 'Arnold Press'),
      _DefaultExerciseSeed('shoulders_lateral_raise', 'Lateral Raise'),
      _DefaultExerciseSeed('shoulders_front_raise', 'Front Raise'),
      _DefaultExerciseSeed('shoulders_rear_delt_fly', 'Rear Delt Fly'),
    ],
    'Legs': [
      _DefaultExerciseSeed('legs_squat', 'Squat'),
      _DefaultExerciseSeed('legs_leg_press', 'Leg Press'),
      _DefaultExerciseSeed('legs_romanian_deadlift', 'Romanian Deadlift'),
      _DefaultExerciseSeed('legs_leg_curl', 'Leg Curl'),
      _DefaultExerciseSeed('legs_leg_extension', 'Leg Extension'),
      _DefaultExerciseSeed('legs_walking_lunges', 'Walking Lunges'),
      _DefaultExerciseSeed('legs_standing_calf_raise', 'Standing Calf Raise'),
    ],
    'Abs': [
      _DefaultExerciseSeed('abs_crunch', 'Crunch', trackingType: 'reps'),
      _DefaultExerciseSeed('abs_cable_crunch', 'Cable Crunch'),
      _DefaultExerciseSeed(
        'abs_hanging_leg_raise',
        'Hanging Leg Raise',
        trackingType: 'reps',
      ),
      _DefaultExerciseSeed('abs_plank', 'Plank', trackingType: 'duration'),
      _DefaultExerciseSeed(
        'abs_russian_twist',
        'Russian Twist',
        trackingType: 'reps',
      ),
      _DefaultExerciseSeed(
        'abs_bicycle_crunch',
        'Bicycle Crunch',
        trackingType: 'reps',
      ),
    ],
    'Cardio': [
      _DefaultExerciseSeed(
        'cardio_running',
        'Running',
        trackingType: 'duration',
      ),
      _DefaultExerciseSeed(
        'cardio_walking',
        'Walking',
        trackingType: 'duration',
      ),
      _DefaultExerciseSeed(
        'cardio_cycling',
        'Cycling',
        trackingType: 'duration',
      ),
      _DefaultExerciseSeed('cardio_rowing', 'Rowing', trackingType: 'duration'),
      _DefaultExerciseSeed(
        'cardio_jump_rope',
        'Jump Rope',
        trackingType: 'duration',
      ),
      _DefaultExerciseSeed(
        'cardio_elliptical',
        'Elliptical',
        trackingType: 'duration',
      ),
    ],
  };

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('repzeno.db');
    return _database!;
  }

  Future<void> closeAndReset() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      var factory = databaseFactoryFfiWeb;
      return await factory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
        ),
      );
    }

    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, filePath);
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
    await _excludeFromBackupIfNeeded(path);
    return db;
  }

  Future<void> _excludeFromBackupIfNeeded(String path) async {
    if (kIsWeb || !Platform.isIOS) {
      return;
    }

    try {
      await _storageProtectionChannel.invokeMethod('excludeFromBackup', {
        'path': path,
      });
    } on PlatformException {
      // If the OS call is unavailable, keep the app functional and continue.
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE muscle_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        muscleGroupId INTEGER NOT NULL,
        isCustom INTEGER NOT NULL DEFAULT 0,
        trackingType TEXT NOT NULL DEFAULT 'weight_reps',
        seedKey TEXT,
        isArchived INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (muscleGroupId) REFERENCES muscle_groups (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutId INTEGER NOT NULL,
        exerciseId INTEGER NOT NULL,
        FOREIGN KEY (workoutId) REFERENCES workouts (id),
        FOREIGN KEY (exerciseId) REFERENCES exercises (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE workout_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workoutExerciseId INTEGER NOT NULL,
        weight REAL,
        reps INTEGER,
        durationSeconds INTEGER,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (workoutExerciseId) REFERENCES workout_exercises (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        height REAL,
        gender TEXT,
        dateOfBirth TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE weight_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight REAL NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE progress_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        category TEXT DEFAULT 'Full Body',
        createdAt TEXT NOT NULL
      )
    ''');

    await _seedDatabase(db);
  }

  Future _seedDatabase(Database db) async {
    final muscleGroupIds = await _ensureDefaultMuscleGroups(db);
    await _syncDefaultExercises(db, muscleGroupIds);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    final muscleGroupIds = await _ensureDefaultMuscleGroups(db);

    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE exercises ADD COLUMN isCustom INTEGER NOT NULL DEFAULT 0',
      );

      // Start by treating existing rows as custom, then mark seeded defaults.
      await db.update('exercises', {'isCustom': 1});
      await _syncDefaultExercises(db, muscleGroupIds);
    }

    if (oldVersion < 3) {
      await _syncDefaultExercises(db, muscleGroupIds);
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE exercises ADD COLUMN seedKey TEXT');
      await db.execute(
        'ALTER TABLE exercises ADD COLUMN isArchived INTEGER NOT NULL DEFAULT 0',
      );
      await _syncDefaultExercises(db, muscleGroupIds);
    }

    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE exercises ADD COLUMN trackingType TEXT NOT NULL DEFAULT 'weight_reps'",
      );

      await db.execute('''
        CREATE TABLE workout_sets_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          workoutExerciseId INTEGER NOT NULL,
          weight REAL,
          reps INTEGER,
          durationSeconds INTEGER,
          createdAt TEXT NOT NULL,
          FOREIGN KEY (workoutExerciseId) REFERENCES workout_exercises (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        INSERT INTO workout_sets_new (id, workoutExerciseId, weight, reps, createdAt)
        SELECT id, workoutExerciseId, weight, reps, createdAt
        FROM workout_sets
      ''');

      await db.execute('DROP TABLE workout_sets');
      await db.execute('ALTER TABLE workout_sets_new RENAME TO workout_sets');

      // For upgrades, only default the new duration exercises when they haven't been used yet.
      await db.execute('''
        UPDATE exercises
        SET trackingType = 'duration'
        WHERE seedKey IN ('abs_plank',
          'cardio_running',
          'cardio_walking',
          'cardio_cycling',
          'cardio_rowing',
          'cardio_jump_rope',
          'cardio_elliptical'
        )
        AND NOT EXISTS (
          SELECT 1
          FROM workout_exercises we
          JOIN workout_sets s ON s.workoutExerciseId = we.id
          WHERE we.exerciseId = exercises.id
          LIMIT 1
        )
      ''');

      await _syncDefaultExercises(db, muscleGroupIds);
    }

    if (oldVersion < 6) {
      // For upgrades, only default the new reps-only exercises when they haven't been used yet.
      await db.execute('''
        UPDATE exercises
        SET trackingType = 'reps'
        WHERE seedKey IN ('chest_push_ups',
          'back_pull_up',
          'triceps_bench_dips',
          'abs_crunch',
          'abs_hanging_leg_raise',
          'abs_russian_twist',
          'abs_bicycle_crunch'
        )
        AND NOT EXISTS (
          SELECT 1
          FROM workout_exercises we
          JOIN workout_sets s ON s.workoutExerciseId = we.id
          WHERE we.exerciseId = exercises.id
          LIMIT 1
        )
      ''');

      await _syncDefaultExercises(db, muscleGroupIds);
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE user_profile (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          height REAL,
          gender TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE weight_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          weight REAL NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 8) {
      await db.execute('ALTER TABLE user_profile ADD COLUMN dateOfBirth TEXT');
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE progress_photos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          path TEXT NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          category TEXT DEFAULT 'Full Body',
          createdAt TEXT NOT NULL
        )
      ''');
    }
  }

  Future<Map<String, int>> _ensureDefaultMuscleGroups(Database db) async {
    final maps = await db.query('muscle_groups');
    final muscleGroupIds = <String, int>{
      for (final map in maps) map['name'] as String: map['id'] as int,
    };

    for (final muscleGroup in _defaultMuscleGroups) {
      if (!muscleGroupIds.containsKey(muscleGroup)) {
        final id = await db.insert('muscle_groups', {'name': muscleGroup});
        muscleGroupIds[muscleGroup] = id;
      }
    }

    return muscleGroupIds;
  }

  Future<void> _syncDefaultExercises(
    Database db,
    Map<String, int> muscleGroupIds,
  ) async {
    final supportsTrackingType = await _tableHasColumn(
      db,
      tableName: 'exercises',
      columnName: 'trackingType',
    );

    for (final entry in _defaultExercises.entries) {
      final muscleGroupId = muscleGroupIds[entry.key];
      if (muscleGroupId == null) {
        continue;
      }

      for (final exercise in entry.value) {
        final existingSeed = await db.query(
          'exercises',
          columns: supportsTrackingType ? ['id', 'trackingType'] : ['id'],
          where: 'seedKey = ?',
          whereArgs: [exercise.key],
          limit: 1,
        );

        if (existingSeed.isNotEmpty) {
          if (supportsTrackingType) {
            final current =
                (existingSeed.first['trackingType'] as String?) ?? '';
            if (current.isEmpty) {
              await db.update(
                'exercises',
                {'trackingType': exercise.trackingType},
                where: 'id = ?',
                whereArgs: [existingSeed.first['id'] as int],
              );
            }
          }
          continue;
        }

        final existing = await db.query(
          'exercises',
          columns: supportsTrackingType
              ? ['id', 'isCustom', 'trackingType']
              : ['id', 'isCustom'],
          where: 'muscleGroupId = ? AND LOWER(name) = LOWER(?)',
          whereArgs: [muscleGroupId, exercise.name],
          limit: 1,
        );

        if (existing.isEmpty) {
          final values = <String, Object?>{
            'name': exercise.name,
            'muscleGroupId': muscleGroupId,
            'isCustom': 0,
            'seedKey': exercise.key,
            'isArchived': 0,
          };
          if (supportsTrackingType) {
            values['trackingType'] = exercise.trackingType;
          }
          await db.insert('exercises', values);
          continue;
        }

        final existingId = existing.first['id'] as int;
        final isCustom = (existing.first['isCustom'] as int?) ?? 0;
        if (isCustom != 0) {
          final values = <String, Object?>{
            'isCustom': 0,
            'seedKey': exercise.key,
          };
          if (supportsTrackingType) {
            values['trackingType'] = exercise.trackingType;
          }
          await db.update(
            'exercises',
            values,
            where: 'id = ?',
            whereArgs: [existingId],
          );
          continue;
        }

        final values = <String, Object?>{'seedKey': exercise.key};
        if (supportsTrackingType) {
          values['trackingType'] = exercise.trackingType;
        }
        await db.update(
          'exercises',
          values,
          where: 'id = ?',
          whereArgs: [existingId],
        );
      }
    }
  }

  Future<bool> _tableHasColumn(
    Database db, {
    required String tableName,
    required String columnName,
  }) async {
    final results = await db.rawQuery('PRAGMA table_info($tableName)');
    return results.any((row) => row['name'] == columnName);
  }

  Future<void> mergeDatabase(String importPath) async {
    final db = await database;
    
    // Attach the secondary database
    final safePath = importPath.replaceAll("'", "''");
    await db.execute("ATTACH DATABASE '$safePath' AS importDb");
    
    try {
      // 1. Merge User Profile
      final localProfile = await db.query('user_profile', limit: 1);
      final importProfile = await db.rawQuery('SELECT * FROM importDb.user_profile LIMIT 1').catchError((_) => <Map<String, dynamic>>[]);
      
      if (importProfile.isNotEmpty) {
        final iProf = importProfile.first;
        bool localHasData = false;
        if (localProfile.isNotEmpty) {
          final lProf = localProfile.first;
          if (lProf['name'] != null || lProf['height'] != null || lProf['gender'] != null || lProf['dateOfBirth'] != null) {
            localHasData = true;
          }
        }
        
        if (!localHasData) {
          final values = {
            'name': iProf['name'],
            'height': iProf['height'],
            'gender': iProf['gender'],
            'dateOfBirth': iProf['dateOfBirth'],
          };
          if (localProfile.isEmpty) {
            await db.insert('user_profile', values);
          } else {
            await db.update('user_profile', values, where: 'id = ?', whereArgs: [localProfile.first['id']]);
          }
        }
      }
      
      // 2. Merge Weight Logs
      final importWL = await db.rawQuery('SELECT * FROM importDb.weight_logs').catchError((_) => <Map<String, dynamic>>[]);
      for (final wl in importWL) {
        final existing = await db.query('weight_logs', where: 'createdAt = ?', whereArgs: [wl['createdAt']], limit: 1);
        if (existing.isEmpty) {
          await db.insert('weight_logs', {
            'date': wl['date'],
            'weight': wl['weight'],
            'createdAt': wl['createdAt'],
          });
        }
      }
      
      // 3. Muscle Groups Mapping
      final importMg = await db.rawQuery('SELECT * FROM importDb.muscle_groups');
      final localMg = await db.query('muscle_groups');
      final mgMap = <int, int>{}; // importId -> localId
      
      for (final iMg in importMg) {
        final iId = iMg['id'] as int;
        final name = iMg['name'] as String;
        final match = localMg.cast<Map<String, dynamic>?>().firstWhere((l) => (l!['name'] as String).toLowerCase() == name.toLowerCase(), orElse: () => null);
        if (match != null) {
          mgMap[iId] = match['id'] as int;
        } else {
          final newId = await db.insert('muscle_groups', {'name': name});
          mgMap[iId] = newId;
        }
      }
      
      // 4. Exercises Mapping
      final importEx = await db.rawQuery('SELECT * FROM importDb.exercises');
      final localEx = await db.query('exercises');
      final exMap = <int, int>{}; // importId -> localId
      
      for (final iEx in importEx) {
        final iId = iEx['id'] as int;
        final name = iEx['name'] as String;
        final oldMgId = iEx['muscleGroupId'] as int;
        final newMgId = mgMap[oldMgId] ?? oldMgId;
        
        final match = localEx.cast<Map<String, dynamic>?>().firstWhere((l) => 
          (l!['name'] as String).toLowerCase() == name.toLowerCase() && l['muscleGroupId'] == newMgId, 
          orElse: () => null);
          
        if (match != null) {
          exMap[iId] = match['id'] as int;
        } else {
           final Map<String, Object?> values = {
            'name': name,
            'muscleGroupId': newMgId,
            'isCustom': iEx['isCustom'],
            'seedKey': iEx['seedKey'],
            'isArchived': iEx['isArchived'] ?? 0,
          };
          if (iEx.containsKey('trackingType')) {
             values['trackingType'] = iEx['trackingType'];
          } else {
             values['trackingType'] = 'weight_reps';
          }
          final newId = await db.insert('exercises', values);
          exMap[iId] = newId;
        }
      }
      
      // 5. Workouts Mapping
      final importWo = await db.rawQuery('SELECT * FROM importDb.workouts');
      final localWo = await db.query('workouts');
      final woMap = <int, int>{};
      
      for (final iWo in importWo) {
        final iId = iWo['id'] as int;
        final date = iWo['date'] as String;
        
        final match = localWo.cast<Map<String, dynamic>?>().firstWhere((l) => l!['date'] == date, orElse: () => null);
        
        if (match != null) {
          woMap[iId] = match['id'] as int;
        } else {
          final newId = await db.insert('workouts', {'date': date});
          woMap[iId] = newId;
        }
      }
      
      // 6. Workout Exercises and Sets
      final importWe = await db.rawQuery('SELECT * FROM importDb.workout_exercises');
      final weMap = <int, int>{};
      
      for (final iWe in importWe) {
        final iId = iWe['id'] as int;
        final oldWoId = iWe['workoutId'] as int;
        final newWoId = woMap[oldWoId];
        final oldExId = iWe['exerciseId'] as int;
        final newExId = exMap[oldExId];
        
        if (newWoId != null && newExId != null) {
          final existingWe = await db.query('workout_exercises', 
            where: 'workoutId = ? AND exerciseId = ?', 
            whereArgs: [newWoId, newExId], limit: 1);
            
          if (existingWe.isNotEmpty) {
             weMap[iId] = existingWe.first['id'] as int;
          } else {
             final newWeId = await db.insert('workout_exercises', {
               'workoutId': newWoId,
               'exerciseId': newExId,
             });
             weMap[iId] = newWeId;
          }
        }
      }
      
      final importSets = await db.rawQuery('SELECT * FROM importDb.workout_sets');
      for (final iSet in importSets) {
        final oldWeId = iSet['workoutExerciseId'] as int;
        final newWeId = weMap[oldWeId];
        
        if (newWeId != null) {
          final createdAt = iSet['createdAt'];
          final existingSet = await db.query('workout_sets',
            where: 'workoutExerciseId = ? AND createdAt = ?',
            whereArgs: [newWeId, createdAt], limit: 1);
            
          if (existingSet.isEmpty) {
            Map<String, Object?> values = {
              'workoutExerciseId': newWeId,
              'weight': iSet['weight'],
              'reps': iSet['reps'],
              'createdAt': createdAt,
            };
            if (iSet.containsKey('durationSeconds')) {
              values['durationSeconds'] = iSet['durationSeconds'];
            }
            await db.insert('workout_sets', values);
          }
        }
      }
      
      // 7. Progress Photos
      final importPp = await db.rawQuery('SELECT * FROM importDb.progress_photos').catchError((_) => <Map<String, dynamic>>[]);
      for (final pp in importPp) {
        final existing = await db.query('progress_photos', where: 'createdAt = ?', whereArgs: [pp['createdAt']], limit: 1);
        if (existing.isEmpty) {
          await db.insert('progress_photos', {
            'path': pp['path'], 
            'date': pp['date'],
            'note': pp['note'],
            'category': pp['category'],
            'createdAt': pp['createdAt'],
          });
        }
      }
      
    } finally {
      await db.execute('DETACH DATABASE importDb');
    }
  }
}

class _DefaultExerciseSeed {
  final String key;
  final String name;
  final String trackingType;

  const _DefaultExerciseSeed(
    this.key,
    this.name, {
    this.trackingType = 'weight_reps',
  });
}
