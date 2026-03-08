import 'package:flutter/material.dart';

import 'package:dullgym/database/database_helper.dart';
import 'package:dullgym/models/models.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  List<Exercise> _exercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    final exercises = await DatabaseHelper.instance.getAllExercises();
    setState(() {
      _exercises = exercises;
      _isLoading = false;
    });
  }

  Future<void> _showExerciseDialog({Exercise? existingExercise}) async {
    final nameController = TextEditingController(text: existingExercise?.name ?? '');
    final muscleGroupController = TextEditingController(text: existingExercise?.muscleGroup ?? '');
    final notesController = TextEditingController(text: existingExercise?.notes ?? '');
    ExerciseType selectedType = existingExercise?.type ?? ExerciseType.repetitionBased;

    final result = await showDialog<Exercise>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingExercise == null ? 'Add Exercise' : 'Edit Exercise'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Exercise Name',
                    hintText: 'e.g., Bench Press',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ExerciseType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ExerciseType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_exerciseTypeDisplayName(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: muscleGroupController,
                  decoration: const InputDecoration(
                    labelText: 'Muscle Group (optional)',
                    hintText: 'e.g., Chest, Back, Legs',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name is required')),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  Exercise(
                    id: existingExercise?.id,
                    name: name,
                    type: selectedType,
                    muscleGroup: muscleGroupController.text.trim().isEmpty
                        ? null
                        : muscleGroupController.text.trim(),
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  ),
                );
              },
              child: Text(existingExercise == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      if (existingExercise == null) {
        await DatabaseHelper.instance.insertExercise(result);
      } else {
        await DatabaseHelper.instance.updateExercise(result);
      }
      _loadExercises();
    }
  }

  Future<void> _deleteExercise(Exercise exercise) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text('Delete "${exercise.name}"? This will also delete all workout sets using this exercise.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && exercise.id != null) {
      await DatabaseHelper.instance.deleteExercise(exercise.id!);
      _loadExercises();
    }
  }

  String _exerciseTypeDisplayName(ExerciseType type) {
    switch (type) {
      case ExerciseType.repetitionBased:
        return 'Reps';
      case ExerciseType.timeBased:
        return 'Timed';
      case ExerciseType.weightedRepetitions:
        return 'Weighted';
      case ExerciseType.distanceBased:
        return 'Distance';
    }
  }

  IconData _exerciseTypeIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.repetitionBased:
        return Icons.repeat;
      case ExerciseType.timeBased:
        return Icons.timer;
      case ExerciseType.weightedRepetitions:
        return Icons.fitness_center;
      case ExerciseType.distanceBased:
        return Icons.straighten;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exercises.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.list,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No exercises yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text('Tap + to add an exercise'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadExercises,
                  child: ListView.builder(
                    itemCount: _exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _exercises[index];
                      return ListTile(
                        leading: Icon(_exerciseTypeIcon(exercise.type)),
                        title: Text(exercise.name),
                        subtitle: Text(
                          [
                            _exerciseTypeDisplayName(exercise.type),
                            if (exercise.muscleGroup != null) exercise.muscleGroup,
                          ].join(' • '),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showExerciseDialog(existingExercise: exercise);
                            } else if (value == 'delete') {
                              _deleteExercise(exercise);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExerciseDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
