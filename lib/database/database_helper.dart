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

  String _csvRow(List<dynamic> values) {
    return const ListToCsvConverter().convert([values]).trim();
  }

  Future<File> exportAllDataToCsv() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/dullgym_export_$timestamp.csv');

    final database = await this.database;
    final buffer = StringBuffer();

    // === EXERCISES ===
    final exercises = await getAllExercises();
    final exerciseMap = {for (final exercise in exercises) exercise.id: exercise};

    buffer.writeln('# EXERCISES');
    buffer.writeln(_csvRow(['Name', 'Type', 'Muscle Group', 'Notes']));
    for (final exercise in exercises) {
      buffer.writeln(_csvRow([
        exercise.name,
        exercise.type.name,
        exercise.muscleGroup ?? '',
        exercise.notes ?? '',
      ]));
    }
    buffer.writeln();

    // === TEMPLATES ===
    final templates = await getAllWorkoutTemplates();
    buffer.writeln('# TEMPLATES');
    buffer.writeln(_csvRow([
      'Template Name', 'Exercise', 'Type', 'Set Order',
      'Target Reps', 'Target Weight (kg)', 'Target Duration (s)', 'Target Distance (m)',
    ]));
    for (final template in templates) {
      final templateSets = await getTemplateSetsForTemplate(template.id!);
      for (final templateSet in templateSets) {
        final exercise = exerciseMap[templateSet.exerciseId];
        buffer.writeln(_csvRow([
          template.name,
          exercise?.name ?? 'Unknown',
          exercise?.type.name ?? '',
          templateSet.setOrder,
          templateSet.targetRepetitions ?? '',
          templateSet.targetWeightInKilograms ?? '',
          templateSet.targetDurationInSeconds ?? '',
          templateSet.targetDistanceInMeters ?? '',
        ]));
      }
    }
    buffer.writeln();

    // === WORKOUTS ===
    final workouts = await getAllWorkouts();
    buffer.writeln('# WORKOUTS');
    buffer.writeln(_csvRow(['Workout Date', 'Duration (s)', 'Notes']));
    for (final workout in workouts) {
      buffer.writeln(_csvRow([
        workout.date.toIso8601String(),
        workout.durationInSeconds,
        workout.notes ?? '',
      ]));
    }
    buffer.writeln();

    // === WORKOUT_SETS ===
    final allSets = await database.query('workout_sets', orderBy: 'workout_id, set_order');
    final workoutMap = {for (final workout in workouts) workout.id: workout};

    buffer.writeln('# WORKOUT_SETS');
    buffer.writeln(_csvRow([
      'Workout Date', 'Exercise', 'Type', 'Set Order',
      'Reps', 'Weight (kg)', 'Duration (s)', 'Distance (m)', 'Notes',
    ]));
    for (final set in allSets) {
      final workout = workoutMap[set['workout_id']];
      final exercise = exerciseMap[set['exercise_id']];
      buffer.writeln(_csvRow([
        workout?.date.toIso8601String() ?? '',
        exercise?.name ?? 'Unknown',
        exercise?.type.name ?? '',
        set['set_order'],
        set['repetitions'] ?? '',
        set['weight_kg'] ?? '',
        set['duration_seconds'] ?? '',
        set['distance_meters'] ?? '',
        set['notes'] ?? '',
      ]));
    }

    await file.writeAsString(buffer.toString());
    return file;
  }

  // ============ CSV Import ============

  Future<void> clearAllData() async {
    final database = await this.database;
    // Delete in order respecting foreign keys
    await database.delete('workout_sets');
    await database.delete('workouts');
    await database.delete('template_sets');
    await database.delete('workout_templates');
    await database.delete('exercises');
  }

  Future<ImportResult> importFromCsv(String filePath, {required bool replaceExisting}) async {
    final file = File(filePath);
    final csvContent = await file.readAsString();

    if (replaceExisting) {
      await clearAllData();
    }

    final database = await this.database;

    // Parse sections
    final sections = _parseCsvSections(csvContent);

    // Track entities for FK resolution
    final exerciseCache = <String, int>{}; // "name|type" -> id
    final templateCache = <String, int>{}; // "name" -> id
    final workoutCache = <String, int>{}; // "date" -> id

    // Load existing entities for merge mode
    if (!replaceExisting) {
      for (final exercise in await getAllExercises()) {
        exerciseCache['${exercise.name}|${exercise.type.name}'] = exercise.id!;
      }
      for (final template in await getAllWorkoutTemplates()) {
        templateCache[template.name] = template.id!;
      }
      for (final workout in await getAllWorkouts()) {
        workoutCache[workout.date.toIso8601String()] = workout.id!;
      }
    }

    int exercisesImported = 0;
    int templatesImported = 0;
    int workoutsImported = 0;
    int setsImported = 0;
    int rowsSkipped = 0;

    // === Import EXERCISES ===
    final exerciseRows = sections['EXERCISES'] ?? [];
    for (final row in exerciseRows) {
      if (row.length < 2) {
        rowsSkipped++;
        continue;
      }
      final name = row[0]?.toString() ?? '';
      final typeStr = row[1]?.toString() ?? '';
      final muscleGroup = row.length > 2 ? row[2]?.toString() : null;
      final notes = row.length > 3 ? row[3]?.toString() : null;

      if (name.isEmpty || typeStr.isEmpty) {
        rowsSkipped++;
        continue;
      }

      final exerciseType = _parseExerciseType(typeStr);
      if (exerciseType == null) {
        rowsSkipped++;
        continue;
      }

      final key = '$name|${exerciseType.name}';
      if (!exerciseCache.containsKey(key)) {
        final id = await database.insert('exercises', {
          'name': name,
          'type': exerciseType.name,
          'muscle_group': muscleGroup?.isNotEmpty == true ? muscleGroup : null,
          'notes': notes?.isNotEmpty == true ? notes : null,
        });
        exerciseCache[key] = id;
        exercisesImported++;
      }
    }

    // === Import TEMPLATES ===
    final templateRows = sections['TEMPLATES'] ?? [];
    for (final row in templateRows) {
      if (row.length < 4) {
        rowsSkipped++;
        continue;
      }
      final templateName = row[0]?.toString() ?? '';
      final exerciseName = row[1]?.toString() ?? '';
      final exerciseTypeStr = row[2]?.toString() ?? '';
      final setOrderStr = row[3]?.toString() ?? '';
      final targetRepsStr = row.length > 4 ? row[4]?.toString() : null;
      final targetWeightStr = row.length > 5 ? row[5]?.toString() : null;
      final targetDurationStr = row.length > 6 ? row[6]?.toString() : null;
      final targetDistanceStr = row.length > 7 ? row[7]?.toString() : null;

      if (templateName.isEmpty || exerciseName.isEmpty) {
        rowsSkipped++;
        continue;
      }

      // Find or create template
      int templateId;
      if (templateCache.containsKey(templateName)) {
        templateId = templateCache[templateName]!;
      } else {
        templateId = await database.insert('workout_templates', {'name': templateName});
        templateCache[templateName] = templateId;
        templatesImported++;
      }

      // Find exercise
      final exerciseKey = '$exerciseName|$exerciseTypeStr';
      final exerciseId = exerciseCache[exerciseKey];
      if (exerciseId == null) {
        rowsSkipped++;
        continue;
      }

      // Create template set
      await database.insert('template_sets', {
        'template_id': templateId,
        'exercise_id': exerciseId,
        'set_order': int.tryParse(setOrderStr) ?? 1,
        'target_repetitions': int.tryParse(targetRepsStr ?? ''),
        'target_weight_kg': double.tryParse(targetWeightStr ?? ''),
        'target_duration_seconds': int.tryParse(targetDurationStr ?? ''),
        'target_distance_meters': double.tryParse(targetDistanceStr ?? ''),
      });
    }

    // === Import WORKOUTS ===
    final workoutRows = sections['WORKOUTS'] ?? [];
    for (final row in workoutRows) {
      if (row.isEmpty) {
        rowsSkipped++;
        continue;
      }
      final dateStr = row[0]?.toString() ?? '';
      final durationStr = row.length > 1 ? row[1]?.toString() : null;
      final notes = row.length > 2 ? row[2]?.toString() : null;

      if (dateStr.isEmpty) {
        rowsSkipped++;
        continue;
      }

      DateTime date;
      try {
        date = DateTime.parse(dateStr);
      } catch (e) {
        rowsSkipped++;
        continue;
      }

      final key = date.toIso8601String();
      if (!workoutCache.containsKey(key)) {
        final id = await database.insert('workouts', {
          'date': key,
          'duration_seconds': int.tryParse(durationStr ?? '') ?? 0,
          'notes': notes?.isNotEmpty == true ? notes : null,
        });
        workoutCache[key] = id;
        workoutsImported++;
      }
    }

    // === Import WORKOUT_SETS ===
    final setRows = sections['WORKOUT_SETS'] ?? [];
    for (final row in setRows) {
      if (row.length < 4) {
        rowsSkipped++;
        continue;
      }
      final workoutDateStr = row[0]?.toString() ?? '';
      final exerciseName = row[1]?.toString() ?? '';
      final exerciseTypeStr = row[2]?.toString() ?? '';
      final setOrderStr = row[3]?.toString() ?? '';
      final repsStr = row.length > 4 ? row[4]?.toString() : null;
      final weightStr = row.length > 5 ? row[5]?.toString() : null;
      final durationStr = row.length > 6 ? row[6]?.toString() : null;
      final distanceStr = row.length > 7 ? row[7]?.toString() : null;
      final notes = row.length > 8 ? row[8]?.toString() : null;

      if (workoutDateStr.isEmpty || exerciseName.isEmpty) {
        rowsSkipped++;
        continue;
      }

      // Find workout
      final workoutId = workoutCache[workoutDateStr];
      if (workoutId == null) {
        rowsSkipped++;
        continue;
      }

      // Find exercise
      final exerciseKey = '$exerciseName|$exerciseTypeStr';
      final exerciseId = exerciseCache[exerciseKey];
      if (exerciseId == null) {
        rowsSkipped++;
        continue;
      }

      await database.insert('workout_sets', {
        'workout_id': workoutId,
        'exercise_id': exerciseId,
        'set_order': int.tryParse(setOrderStr) ?? 1,
        'repetitions': int.tryParse(repsStr ?? ''),
        'weight_kg': double.tryParse(weightStr ?? ''),
        'duration_seconds': int.tryParse(durationStr ?? ''),
        'distance_meters': double.tryParse(distanceStr ?? ''),
        'notes': notes?.isNotEmpty == true ? notes : null,
      });
      setsImported++;
    }

    return ImportResult(
      exercisesImported: exercisesImported,
      templatesImported: templatesImported,
      workoutsImported: workoutsImported,
      setsImported: setsImported,
      rowsSkipped: rowsSkipped,
    );
  }

  /// Parses CSV content into sections based on `# SECTION_NAME` markers.
  Map<String, List<List<dynamic>>> _parseCsvSections(String content) {
    final sections = <String, List<List<dynamic>>>{};
    final lines = content.split('\n');
    String? currentSection;
    final currentRows = <String>[];

    for (final line in lines) {
      if (line.startsWith('# ')) {
        // Save previous section
        if (currentSection != null && currentRows.isNotEmpty) {
          final parsed = const CsvToListConverter().convert(currentRows.join('\n'));
          // Skip header row
          sections[currentSection] = parsed.length > 1 ? parsed.sublist(1) : [];
        }
        currentSection = line.substring(2).trim();
        currentRows.clear();
      } else if (currentSection != null && line.trim().isNotEmpty) {
        currentRows.add(line);
      }
    }

    // Save last section
    if (currentSection != null && currentRows.isNotEmpty) {
      final parsed = const CsvToListConverter().convert(currentRows.join('\n'));
      sections[currentSection] = parsed.length > 1 ? parsed.sublist(1) : [];
    }

    return sections;
  }

  ExerciseType? _parseExerciseType(String typeStr) {
    for (final type in ExerciseType.values) {
      if (type.name == typeStr) {
        return type;
      }
    }
    return null;
  }
}

class ImportResult {
  final int exercisesImported;
  final int templatesImported;
  final int workoutsImported;
  final int setsImported;
  final int rowsSkipped;

  const ImportResult({
    required this.exercisesImported,
    required this.templatesImported,
    required this.workoutsImported,
    required this.setsImported,
    required this.rowsSkipped,
  });
}
