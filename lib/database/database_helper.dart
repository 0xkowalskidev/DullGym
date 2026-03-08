import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:dullgym/models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'dullgym.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database database, int version) async {
    await database.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        muscle_group TEXT,
        notes TEXT
      )
    ''');

    await database.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        notes TEXT,
        duration_seconds INTEGER DEFAULT 0
      )
    ''');

    await database.execute('''
      CREATE TABLE workout_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        set_order INTEGER NOT NULL,
        repetitions INTEGER,
        weight_kg REAL,
        duration_seconds INTEGER,
        distance_meters REAL,
        notes TEXT,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_workout_sets_workout_id ON workout_sets (workout_id)
    ''');

    await database.execute('''
      CREATE INDEX idx_workout_sets_exercise_id ON workout_sets (exercise_id)
    ''');

    await _createTemplateTables(database);
    await _insertDefaultExercises(database);
  }

  Future<void> _upgradeDatabase(Database database, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createLegacyTemplateTables(database);
    }
    if (oldVersion < 3) {
      await _migrateToTemplateSets(database);
    }
    if (oldVersion < 4) {
      await _addDistanceColumns(database);
    }
  }

  Future<void> _addDistanceColumns(Database database) async {
    await database.execute('ALTER TABLE workout_sets ADD COLUMN distance_meters REAL');
    await database.execute('ALTER TABLE template_sets ADD COLUMN target_distance_meters REAL');

    // Add Running (Distance) exercise
    await database.insert('exercises', {
      'name': 'Running (Distance)',
      'type': 'distanceBased',
      'muscle_group': 'Cardio',
    });
  }

  Future<void> _createLegacyTemplateTables(Database database) async {
    await database.execute('''
      CREATE TABLE workout_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE template_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        exercise_order INTEGER NOT NULL,
        set_count INTEGER NOT NULL DEFAULT 1,
        target_repetitions INTEGER,
        target_weight_kg REAL,
        target_duration_seconds INTEGER,
        FOREIGN KEY (template_id) REFERENCES workout_templates (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_template_exercises_template_id ON template_exercises (template_id)
    ''');
  }

  Future<void> _migrateToTemplateSets(Database database) async {
    // Create new template_sets table
    await database.execute('''
      CREATE TABLE template_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        set_order INTEGER NOT NULL,
        target_repetitions INTEGER,
        target_weight_kg REAL,
        target_duration_seconds INTEGER,
        FOREIGN KEY (template_id) REFERENCES workout_templates (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_template_sets_template_id ON template_sets (template_id)
    ''');

    // Migrate data from template_exercises to template_sets
    final oldData = await database.query('template_exercises', orderBy: 'template_id, exercise_order');
    int setOrder = 0;
    int? currentTemplateId;

    for (final row in oldData) {
      final templateId = row['template_id'] as int;
      if (templateId != currentTemplateId) {
        setOrder = 0;
        currentTemplateId = templateId;
      }

      final setCount = row['set_count'] as int? ?? 1;
      for (int i = 0; i < setCount; i++) {
        setOrder++;
        await database.insert('template_sets', {
          'template_id': templateId,
          'exercise_id': row['exercise_id'],
          'set_order': setOrder,
          'target_repetitions': row['target_repetitions'],
          'target_weight_kg': row['target_weight_kg'],
          'target_duration_seconds': row['target_duration_seconds'],
        });
      }
    }

    // Drop old table
    await database.execute('DROP TABLE template_exercises');
  }

  Future<void> _createTemplateTables(Database database) async {
    await database.execute('''
      CREATE TABLE workout_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE template_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        set_order INTEGER NOT NULL,
        target_repetitions INTEGER,
        target_weight_kg REAL,
        target_duration_seconds INTEGER,
        target_distance_meters REAL,
        FOREIGN KEY (template_id) REFERENCES workout_templates (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_template_sets_template_id ON template_sets (template_id)
    ''');
  }

  Future<void> _insertDefaultExercises(Database database) async {
    final defaultExercises = [
      const Exercise(name: 'Push-ups', type: ExerciseType.repetitionBased, muscleGroup: 'Chest'),
      const Exercise(name: 'Pull-ups', type: ExerciseType.repetitionBased, muscleGroup: 'Back'),
      const Exercise(name: 'Squats', type: ExerciseType.repetitionBased, muscleGroup: 'Legs'),
      const Exercise(name: 'Plank', type: ExerciseType.timeBased, muscleGroup: 'Core'),
      const Exercise(name: 'Bench Press', type: ExerciseType.weightedRepetitions, muscleGroup: 'Chest'),
      const Exercise(name: 'Deadlift', type: ExerciseType.weightedRepetitions, muscleGroup: 'Back'),
      const Exercise(name: 'Barbell Squat', type: ExerciseType.weightedRepetitions, muscleGroup: 'Legs'),
      const Exercise(name: 'Running (Timed)', type: ExerciseType.timeBased, muscleGroup: 'Cardio'),
      const Exercise(name: 'Running (Distance)', type: ExerciseType.distanceBased, muscleGroup: 'Cardio'),
    ];

    for (final exercise in defaultExercises) {
      await database.insert('exercises', exercise.toMap()..remove('id'));
    }
  }

  // ============ Exercise CRUD ============

  Future<int> insertExercise(Exercise exercise) async {
    final database = await this.database;
    final map = exercise.toMap()..remove('id');
    return await database.insert('exercises', map);
  }

  Future<List<Exercise>> getAllExercises() async {
    final database = await this.database;
    final maps = await database.query('exercises', orderBy: 'name ASC');
    return maps.map((map) => Exercise.fromMap(map)).toList();
  }

  Future<Exercise?> getExerciseById(int id) async {
    final database = await this.database;
    final maps = await database.query('exercises', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Exercise.fromMap(maps.first);
  }

  Future<int> updateExercise(Exercise exercise) async {
    if (exercise.id == null) {
      throw ArgumentError('Cannot update exercise without id');
    }
    final database = await this.database;
    return await database.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<int> deleteExercise(int id) async {
    final database = await this.database;
    return await database.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // ============ Workout CRUD ============

  Future<int> insertWorkout(Workout workout) async {
    final database = await this.database;
    final map = workout.toMap()..remove('id');
    return await database.insert('workouts', map);
  }

  Future<List<Workout>> getAllWorkouts() async {
    final database = await this.database;
    final maps = await database.query('workouts', orderBy: 'date DESC');
    return maps.map((map) => Workout.fromMap(map)).toList();
  }

  Future<Workout?> getWorkoutById(int id) async {
    final database = await this.database;
    final maps = await database.query('workouts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Workout.fromMap(maps.first);
  }

  Future<int> updateWorkout(Workout workout) async {
    if (workout.id == null) {
      throw ArgumentError('Cannot update workout without id');
    }
    final database = await this.database;
    return await database.update(
      'workouts',
      workout.toMap(),
      where: 'id = ?',
      whereArgs: [workout.id],
    );
  }

  Future<int> deleteWorkout(int id) async {
    final database = await this.database;
    return await database.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  // ============ WorkoutSet CRUD ============

  Future<int> insertWorkoutSet(WorkoutSet workoutSet) async {
    final database = await this.database;
    final map = workoutSet.toMap()..remove('id');
    return await database.insert('workout_sets', map);
  }

  Future<List<WorkoutSet>> getWorkoutSetsForWorkout(int workoutId) async {
    final database = await this.database;
    final maps = await database.query(
      'workout_sets',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'set_order ASC',
    );
    return maps.map((map) => WorkoutSet.fromMap(map)).toList();
  }

  Future<List<WorkoutSet>> getWorkoutSetsForExercise(int exerciseId) async {
    final database = await this.database;
    final maps = await database.query(
      'workout_sets',
      where: 'exercise_id = ?',
      whereArgs: [exerciseId],
      orderBy: 'id DESC',
    );
    return maps.map((map) => WorkoutSet.fromMap(map)).toList();
  }

  Future<int> updateWorkoutSet(WorkoutSet workoutSet) async {
    if (workoutSet.id == null) {
      throw ArgumentError('Cannot update workout set without id');
    }
    final database = await this.database;
    return await database.update(
      'workout_sets',
      workoutSet.toMap(),
      where: 'id = ?',
      whereArgs: [workoutSet.id],
    );
  }

  Future<int> deleteWorkoutSet(int id) async {
    final database = await this.database;
    return await database.delete('workout_sets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteWorkoutSetsForWorkout(int workoutId) async {
    final database = await this.database;
    await database.delete('workout_sets', where: 'workout_id = ?', whereArgs: [workoutId]);
  }

  // ============ WorkoutTemplate CRUD ============

  Future<int> insertWorkoutTemplate(WorkoutTemplate template) async {
    final database = await this.database;
    final map = template.toMap()..remove('id');
    return await database.insert('workout_templates', map);
  }

  Future<List<WorkoutTemplate>> getAllWorkoutTemplates() async {
    final database = await this.database;
    final maps = await database.query('workout_templates', orderBy: 'name ASC');
    return maps.map((map) => WorkoutTemplate.fromMap(map)).toList();
  }

  Future<WorkoutTemplate?> getWorkoutTemplateById(int id) async {
    final database = await this.database;
    final maps = await database.query('workout_templates', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return WorkoutTemplate.fromMap(maps.first);
  }

  Future<int> updateWorkoutTemplate(WorkoutTemplate template) async {
    if (template.id == null) {
      throw ArgumentError('Cannot update template without id');
    }
    final database = await this.database;
    return await database.update(
      'workout_templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  Future<int> deleteWorkoutTemplate(int id) async {
    final database = await this.database;
    return await database.delete('workout_templates', where: 'id = ?', whereArgs: [id]);
  }

  // ============ TemplateSet CRUD ============

  Future<int> insertTemplateSet(TemplateSet templateSet) async {
    final database = await this.database;
    final map = templateSet.toMap()..remove('id');
    return await database.insert('template_sets', map);
  }

  Future<List<TemplateSet>> getTemplateSetsForTemplate(int templateId) async {
    final database = await this.database;
    final maps = await database.query(
      'template_sets',
      where: 'template_id = ?',
      whereArgs: [templateId],
      orderBy: 'set_order ASC',
    );
    return maps.map((map) => TemplateSet.fromMap(map)).toList();
  }

  Future<int> updateTemplateSet(TemplateSet templateSet) async {
    if (templateSet.id == null) {
      throw ArgumentError('Cannot update template set without id');
    }
    final database = await this.database;
    return await database.update(
      'template_sets',
      templateSet.toMap(),
      where: 'id = ?',
      whereArgs: [templateSet.id],
    );
  }

  Future<int> deleteTemplateSet(int id) async {
    final database = await this.database;
    return await database.delete('template_sets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTemplateSetsForTemplate(int templateId) async {
    final database = await this.database;
    await database.delete('template_sets', where: 'template_id = ?', whereArgs: [templateId]);
  }

  // ============ CSV Export ============

  Future<File> exportAllDataToCsv() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/dullgym_export_$timestamp.csv');

    final exercises = await getAllExercises();
    final workouts = await getAllWorkouts();
    final database = await this.database;
    final allSets = await database.query('workout_sets');

    final exerciseMap = {for (final exercise in exercises) exercise.id: exercise};

    final rows = <List<dynamic>>[
      ['Workout Date', 'Exercise', 'Exercise Type', 'Muscle Group', 'Set #', 'Reps', 'Weight (kg)', 'Duration (s)', 'Distance (m)', 'Notes'],
    ];

    for (final workout in workouts) {
      final sets = allSets.where((set) => set['workout_id'] == workout.id).toList();

      if (sets.isEmpty) {
        rows.add([
          workout.date.toIso8601String(),
          '', '', '', '', '', '', '', '',
          workout.notes ?? '',
        ]);
      } else {
        for (final set in sets) {
          final exercise = exerciseMap[set['exercise_id']];
          rows.add([
            workout.date.toIso8601String(),
            exercise?.name ?? 'Unknown',
            exercise?.type.name ?? '',
            exercise?.muscleGroup ?? '',
            set['set_order'],
            set['repetitions'] ?? '',
            set['weight_kg'] ?? '',
            set['duration_seconds'] ?? '',
            set['distance_meters'] ?? '',
            set['notes'] ?? '',
          ]);
        }
      }
    }

    final csvString = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csvString);
    return file;
  }
}
