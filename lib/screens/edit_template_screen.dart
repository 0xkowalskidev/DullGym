import 'package:flutter/material.dart';

import 'package:dullgym/database/database_helper.dart';
import 'package:dullgym/models/models.dart';

class EditTemplateScreen extends StatefulWidget {
  final WorkoutTemplate? existingTemplate;

  const EditTemplateScreen({super.key, this.existingTemplate});

  @override
  State<EditTemplateScreen> createState() => _EditTemplateScreenState();
}

class _PendingTemplateSet {
  final Exercise exercise;
  int? targetRepetitions;
  double? targetWeightInKilograms;
  int? targetDurationInSeconds;
  double? targetDistanceInMeters;

  _PendingTemplateSet({
    required this.exercise,
    this.targetRepetitions,
    this.targetWeightInKilograms,
    this.targetDurationInSeconds,
    this.targetDistanceInMeters,
  });
}

class _EditTemplateScreenState extends State<EditTemplateScreen> {
  final _nameController = TextEditingController();
  final List<_PendingTemplateSet> _sets = [];
  List<Exercise> _availableExercises = [];
  bool _isLoading = true;

  bool get _isEditing => widget.existingTemplate != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final exercises = await DatabaseHelper.instance.getAllExercises();
    final exerciseMap = {for (final exercise in exercises) exercise.id: exercise};

    if (_isEditing) {
      _nameController.text = widget.existingTemplate!.name;
      final templateSets = await DatabaseHelper.instance
          .getTemplateSetsForTemplate(widget.existingTemplate!.id!);

      for (final templateSet in templateSets) {
        final exercise = exerciseMap[templateSet.exerciseId];
        if (exercise != null) {
          _sets.add(_PendingTemplateSet(
            exercise: exercise,
            targetRepetitions: templateSet.targetRepetitions,
            targetWeightInKilograms: templateSet.targetWeightInKilograms,
            targetDurationInSeconds: templateSet.targetDurationInSeconds,
            targetDistanceInMeters: templateSet.targetDistanceInMeters,
          ));
        }
      }
    }

    setState(() {
      _availableExercises = exercises;
      _isLoading = false;
    });
  }

  Future<void> _addExercise() async {
    if (_availableExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some exercises first')),
      );
      return;
    }

    final selectedExercise = await showDialog<Exercise>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Exercise'),
        children: _availableExercises.map((exercise) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, exercise),
            child: Text(exercise.name),
          );
        }).toList(),
      ),
    );

    if (selectedExercise != null) {
      setState(() {
        _sets.add(_PendingTemplateSet(exercise: selectedExercise));
      });
    }
  }

  void _addSetForExercise(Exercise exercise) {
    // Find the last set for this exercise to copy values
    _PendingTemplateSet? lastSet;
    for (final set in _sets.reversed) {
      if (set.exercise.id == exercise.id) {
        lastSet = set;
        break;
      }
    }

    setState(() {
      _sets.add(_PendingTemplateSet(
        exercise: exercise,
        targetRepetitions: lastSet?.targetRepetitions,
        targetWeightInKilograms: lastSet?.targetWeightInKilograms,
        targetDurationInSeconds: lastSet?.targetDurationInSeconds,
        targetDistanceInMeters: lastSet?.targetDistanceInMeters,
      ));
    });
  }

  void _removeSet(int index) {
    setState(() {
      _sets.removeAt(index);
    });
  }

  void _removeExercise(int exerciseId) {
    setState(() {
      _sets.removeWhere((set) => set.exercise.id == exerciseId);
    });
  }

  /// Groups sets by exercise, preserving insertion order.
  List<(Exercise, List<(int, _PendingTemplateSet)>)> _groupSetsByExercise() {
    final Map<int, List<(int, _PendingTemplateSet)>> grouped = {};
    final List<int> exerciseOrder = [];

    for (int i = 0; i < _sets.length; i++) {
      final set = _sets[i];
      final exerciseId = set.exercise.id!;
      if (!grouped.containsKey(exerciseId)) {
        grouped[exerciseId] = [];
        exerciseOrder.add(exerciseId);
      }
      grouped[exerciseId]!.add((i, set));
    }

    return exerciseOrder.map((id) {
      final sets = grouped[id]!;
      return (sets.first.$2.exercise, sets);
    }).toList();
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    final groups = _groupSetsByExercise();
    if (newIndex > oldIndex) newIndex--;

    final movedGroup = groups.removeAt(oldIndex);
    groups.insert(newIndex, movedGroup);

    // Rebuild _sets in new order
    final newSets = <_PendingTemplateSet>[];
    for (final (_, indexedSets) in groups) {
      for (final (_, set) in indexedSets) {
        newSets.add(set);
      }
    }

    setState(() {
      _sets.clear();
      _sets.addAll(newSets);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a template name')),
      );
      return;
    }

    if (_sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one set')),
      );
      return;
    }

    int templateId;
    if (_isEditing) {
      final updatedTemplate = widget.existingTemplate!.copyWith(name: name);
      await DatabaseHelper.instance.updateWorkoutTemplate(updatedTemplate);
      await DatabaseHelper.instance.deleteTemplateSetsForTemplate(updatedTemplate.id!);
      templateId = updatedTemplate.id!;
    } else {
      final newTemplate = WorkoutTemplate(name: name);
      templateId = await DatabaseHelper.instance.insertWorkoutTemplate(newTemplate);
    }

    for (int i = 0; i < _sets.length; i++) {
      final set = _sets[i];
      final templateSet = TemplateSet(
        templateId: templateId,
        exerciseId: set.exercise.id!,
        setOrder: i + 1,
        targetRepetitions: set.targetRepetitions,
        targetWeightInKilograms: set.targetWeightInKilograms,
        targetDurationInSeconds: set.targetDurationInSeconds,
        targetDistanceInMeters: set.targetDistanceInMeters,
      );
      await DatabaseHelper.instance.insertTemplateSet(templateSet);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _deleteTemplate() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Delete "${widget.existingTemplate!.name}"?'),
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

    if (shouldDelete == true) {
      await DatabaseHelper.instance.deleteWorkoutTemplate(widget.existingTemplate!.id!);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Template' : 'New Template'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _deleteTemplate,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete template',
            ),
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Template Name',
                      hintText: 'e.g., Leg Day, Push Day',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: !_isEditing,
                  ),
                ),
                Expanded(
                  child: _sets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              const Text('No exercises yet'),
                              const SizedBox(height: 8),
                              const Text('Tap + to add an exercise'),
                            ],
                          ),
                        )
                      : Builder(builder: (context) {
                          final groups = _groupSetsByExercise();
                          return ReorderableListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: groups.length,
                            onReorder: _reorderExercises,
                            itemBuilder: (context, groupIndex) {
                              final (exercise, indexedSets) = groups[groupIndex];
                              return _TemplateExerciseCard(
                                key: ValueKey(exercise.id),
                                exercise: exercise,
                                indexedSets: indexedSets,
                                onRemoveSet: _removeSet,
                                onRemoveExercise: () => _removeExercise(exercise.id!),
                                onAddSet: () => _addSetForExercise(exercise),
                                onChanged: () => setState(() {}),
                              );
                            },
                          );
                        }),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Exercise'),
      ),
    );
  }
}

class _TemplateExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final List<(int, _PendingTemplateSet)> indexedSets;
  final void Function(int) onRemoveSet;
  final VoidCallback onRemoveExercise;
  final VoidCallback onAddSet;
  final VoidCallback onChanged;

  const _TemplateExerciseCard({
    super.key,
    required this.exercise,
    required this.indexedSets,
    required this.onRemoveSet,
    required this.onRemoveExercise,
    required this.onAddSet,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Exercise header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: colorScheme.primaryContainer,
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: 0,
                  child: Icon(
                    Icons.drag_handle,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onPrimaryContainer),
                  onPressed: onRemoveExercise,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Set rows
          ...indexedSets.asMap().entries.map((entry) {
            final setNumber = entry.key + 1;
            final (globalIndex, pendingSet) = entry.value;
            return _TemplateSetRow(
              setNumber: setNumber,
              pendingSet: pendingSet,
              showRemove: indexedSets.length > 1,
              onRemove: () => onRemoveSet(globalIndex),
              onChanged: onChanged,
            );
          }),
          // Add set button
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Set'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateSetRow extends StatelessWidget {
  final int setNumber;
  final _PendingTemplateSet pendingSet;
  final bool showRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _TemplateSetRow({
    required this.setNumber,
    required this.pendingSet,
    required this.showRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Set number
          SizedBox(
            width: 28,
            child: Text(
              '$setNumber',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          // Input fields
          Expanded(child: _buildInputFields(context)),
          // Delete button (only if more than 1 set)
          if (showRemove)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            )
          else
            const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildInputFields(BuildContext context) {
    switch (pendingSet.exercise.type) {
      case ExerciseType.repetitionBased:
        return TextFormField(
          initialValue: pendingSet.targetRepetitions?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Reps',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          keyboardType: TextInputType.number,
          onChanged: (text) {
            pendingSet.targetRepetitions = int.tryParse(text);
            onChanged();
          },
        );

      case ExerciseType.timeBased:
        return TextFormField(
          initialValue: pendingSet.targetDurationInSeconds?.toString() ?? '',
          decoration: const InputDecoration(
            labelText: 'Seconds',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          keyboardType: TextInputType.number,
          onChanged: (text) {
            pendingSet.targetDurationInSeconds = int.tryParse(text);
            onChanged();
          },
        );

      case ExerciseType.distanceBased:
        // Display in km but store in meters
        final displayValue = pendingSet.targetDistanceInMeters != null
            ? (pendingSet.targetDistanceInMeters! / 1000).toStringAsFixed(2)
            : '';
        return TextFormField(
          initialValue: displayValue,
          decoration: const InputDecoration(
            labelText: 'km',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (text) {
            final km = double.tryParse(text);
            pendingSet.targetDistanceInMeters = km != null ? km * 1000 : null;
            onChanged();
          },
        );

      case ExerciseType.weightedRepetitions:
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: pendingSet.targetRepetitions?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Reps',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                onChanged: (text) {
                  pendingSet.targetRepetitions = int.tryParse(text);
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: pendingSet.targetWeightInKilograms?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'kg',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (text) {
                  pendingSet.targetWeightInKilograms = double.tryParse(text);
                  onChanged();
                },
              ),
            ),
          ],
        );
    }
  }
}
