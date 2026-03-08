import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

import 'package:dullgym/database/database_helper.dart';
import 'package:dullgym/models/models.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final List<TemplateSet>? templateSets;

  const ActiveWorkoutScreen({super.key, this.templateSets});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _PendingSet {
  final Exercise exercise;
  int? repetitions;
  double? weightInKilograms;
  int? durationInSeconds;
  double? distanceInMeters;
  bool isCompleted;

  _PendingSet({
    required this.exercise,
    this.repetitions,
    this.weightInKilograms,
    this.durationInSeconds,
    this.distanceInMeters,
    this.isCompleted = false,
  });
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final List<_PendingSet> _sets = [];
  List<Exercise> _availableExercises = [];
  final DateTime _workoutStartTime = DateTime.now();
  Timer? _durationTimer;
  int _elapsedSeconds = 0;

  // Rest timer state
  Timer? _restTimer;
  int _restDurationSeconds = 60;
  int? _restSecondsRemaining;

  // Activity timer state (for time-based exercises)
  Timer? _activityTimer;
  int? _activeTimerSetIndex;
  int? _activitySecondsRemaining;

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _startTimer();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _restTimer?.cancel();
    _activityTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_workoutStartTime).inSeconds;
      });
    });
  }

  // Rest timer methods
  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = _restDurationSeconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining! > 0) {
        setState(() {
          _restSecondsRemaining = _restSecondsRemaining! - 1;
        });
      } else {
        _stopRestTimer();
        _playTimerCompleteAlert();
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
    setState(() {
      _restSecondsRemaining = null;
    });
  }

  void _adjustRestDuration(int delta) {
    setState(() {
      _restDurationSeconds = (_restDurationSeconds + delta).clamp(15, 300);
      if (_restSecondsRemaining != null) {
        _restSecondsRemaining = (_restSecondsRemaining! + delta).clamp(0, 300);
      }
    });
  }

  // Activity timer methods (for time-based exercises)
  void _startActivityTimer(int setIndex, int targetSeconds) {
    _activityTimer?.cancel();
    setState(() {
      _activeTimerSetIndex = setIndex;
      _activitySecondsRemaining = targetSeconds;
    });
    _activityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_activitySecondsRemaining! > 0) {
          _activitySecondsRemaining = _activitySecondsRemaining! - 1;
        } else {
          _completeActivityTimer();
        }
      });
    });
  }

  void _stopActivityTimer() {
    _activityTimer?.cancel();
    _activityTimer = null;
    setState(() {
      _activeTimerSetIndex = null;
      _activitySecondsRemaining = null;
    });
  }

  void _completeActivityTimer() {
    final setIndex = _activeTimerSetIndex;
    _stopActivityTimer();
    _playTimerCompleteAlert();
    if (setIndex != null && setIndex < _sets.length) {
      setState(() {
        _sets[setIndex].isCompleted = true;
      });
      _startRestTimer();
    }
  }

  void _playTimerCompleteAlert() {
    Vibration.vibrate(duration: 500);
    FlutterRingtonePlayer().playNotification();
  }

  Future<void> _loadExercises() async {
    final exercises = await DatabaseHelper.instance.getAllExercises();
    final exerciseMap = {for (final e in exercises) e.id: e};

    if (widget.templateSets != null) {
      for (final templateSet in widget.templateSets!) {
        final exercise = exerciseMap[templateSet.exerciseId];
        if (exercise != null) {
          _sets.add(_PendingSet(
            exercise: exercise,
            repetitions: templateSet.targetRepetitions,
            weightInKilograms: templateSet.targetWeightInKilograms,
            durationInSeconds: templateSet.targetDurationInSeconds,
            distanceInMeters: templateSet.targetDistanceInMeters,
          ));
        }
      }
    }

    setState(() {
      _availableExercises = exercises;
    });
  }

  Future<void> _addSet() async {
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
        _sets.add(_PendingSet(exercise: selectedExercise));
      });
    }
  }

  void _removeSet(int index) {
    setState(() {
      _sets.removeAt(index);
    });
  }

  Future<void> _saveWorkout() async {
    if (_sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one set')),
      );
      return;
    }

    final workout = Workout(
      date: _workoutStartTime,
      durationInSeconds: _elapsedSeconds,
    );

    final workoutId = await DatabaseHelper.instance.insertWorkout(workout);

    for (int i = 0; i < _sets.length; i++) {
      final pendingSet = _sets[i];
      final workoutSet = WorkoutSet(
        workoutId: workoutId,
        exerciseId: pendingSet.exercise.id!,
        setOrder: i + 1,
        repetitions: pendingSet.repetitions,
        weightInKilograms: pendingSet.weightInKilograms,
        durationInSeconds: pendingSet.durationInSeconds,
        distanceInMeters: pendingSet.distanceInMeters,
      );
      await DatabaseHelper.instance.insertWorkoutSet(workoutSet);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<bool> _confirmDiscard() async {
    if (_sets.isEmpty) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Workout?'),
        content: const Text('You have unsaved sets. Discard this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  String _formatElapsedTime() {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Groups sets by exercise, preserving insertion order.
  /// Returns list of (Exercise, List<(index, _PendingSet)>) pairs.
  List<(Exercise, List<(int, _PendingSet)>)> _groupSetsByExercise() {
    final Map<int, List<(int, _PendingSet)>> grouped = {};
    final List<int> exerciseOrder = [];

    for (int i = 0; i < _sets.length; i++) {
      final pendingSet = _sets[i];
      final exerciseId = pendingSet.exercise.id!;
      if (!grouped.containsKey(exerciseId)) {
        grouped[exerciseId] = [];
        exerciseOrder.add(exerciseId);
      }
      grouped[exerciseId]!.add((i, pendingSet));
    }

    return exerciseOrder.map((id) {
      final sets = grouped[id]!;
      return (sets.first.$2.exercise, sets);
    }).toList();
  }

  void _addSetForExercise(Exercise exercise) {
    // Find the last set for this exercise to copy values
    _PendingSet? lastSet;
    for (final set in _sets.reversed) {
      if (set.exercise.id == exercise.id) {
        lastSet = set;
        break;
      }
    }

    setState(() {
      _sets.add(_PendingSet(
        exercise: exercise,
        repetitions: lastSet?.repetitions,
        weightInKilograms: lastSet?.weightInKilograms,
        durationInSeconds: lastSet?.durationInSeconds,
        distanceInMeters: lastSet?.distanceInMeters,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard()) {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_formatElapsedTime()),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _saveWorkout,
              child: const Text('Finish'),
            ),
          ],
        ),
        body: Column(
          children: [
            // Rest timer banner
            if (_restSecondsRemaining != null)
              _RestTimerBanner(
                secondsRemaining: _restSecondsRemaining!,
                onAdjust: _adjustRestDuration,
                onSkip: _stopRestTimer,
              ),
            // Main content
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
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: groups.length,
                        itemBuilder: (context, groupIndex) {
                          final (exercise, indexedSets) = groups[groupIndex];
                          final allCompleted = indexedSets.every((s) => s.$2.isCompleted);
                          return _ExerciseGroupCard(
                            exercise: exercise,
                            indexedSets: indexedSets,
                            allCompleted: allCompleted,
                            onRemoveSet: _removeSet,
                            onToggleComplete: (index) {
                              final wasCompleted = _sets[index].isCompleted;
                              setState(() {
                                _sets[index].isCompleted = !wasCompleted;
                              });
                              // Start rest timer when marking a set complete
                              if (!wasCompleted) {
                                _startRestTimer();
                              }
                            },
                            onChanged: () => setState(() {}),
                            onAddSet: () => _addSetForExercise(exercise),
                            activeTimerSetIndex: _activeTimerSetIndex,
                            activitySecondsRemaining: _activitySecondsRemaining,
                            onStartActivityTimer: _startActivityTimer,
                            onStopActivityTimer: _stopActivityTimer,
                          );
                        },
                      );
                    }),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addSet,
          icon: const Icon(Icons.add),
          label: const Text('Exercise'),
        ),
      ),
    );
  }
}

class _RestTimerBanner extends StatelessWidget {
  final int secondsRemaining;
  final void Function(int) onAdjust;
  final VoidCallback onSkip;

  const _RestTimerBanner({
    required this.secondsRemaining,
    required this.onAdjust,
    required this.onSkip,
  });

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.secondaryContainer,
      child: Row(
        children: [
          Icon(Icons.timer, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Text(
            'Rest: ${_formatTime(secondsRemaining)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => onAdjust(-15),
            icon: const Icon(Icons.remove),
            visualDensity: VisualDensity.compact,
            tooltip: '-15s',
          ),
          IconButton(
            onPressed: () => onAdjust(15),
            icon: const Icon(Icons.add),
            visualDensity: VisualDensity.compact,
            tooltip: '+15s',
          ),
          TextButton(
            onPressed: onSkip,
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}

class _ExerciseGroupCard extends StatelessWidget {
  final Exercise exercise;
  final List<(int, _PendingSet)> indexedSets;
  final bool allCompleted;
  final void Function(int) onRemoveSet;
  final void Function(int) onToggleComplete;
  final VoidCallback onChanged;
  final VoidCallback onAddSet;
  final int? activeTimerSetIndex;
  final int? activitySecondsRemaining;
  final void Function(int, int) onStartActivityTimer;
  final VoidCallback onStopActivityTimer;

  const _ExerciseGroupCard({
    required this.exercise,
    required this.indexedSets,
    required this.allCompleted,
    required this.onRemoveSet,
    required this.onToggleComplete,
    required this.onChanged,
    required this.onAddSet,
    required this.activeTimerSetIndex,
    required this.activitySecondsRemaining,
    required this.onStartActivityTimer,
    required this.onStopActivityTimer,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: allCompleted
                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                : colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
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
                if (allCompleted)
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: colorScheme.primary,
                  ),
              ],
            ),
          ),
          // Set rows
          ...indexedSets.asMap().entries.map((entry) {
            final setNumber = entry.key + 1;
            final (globalIndex, pendingSet) = entry.value;
            final isTimerActive = activeTimerSetIndex == globalIndex;
            return _SetRow(
              setNumber: setNumber,
              pendingSet: pendingSet,
              onRemove: () => onRemoveSet(globalIndex),
              onToggleComplete: () => onToggleComplete(globalIndex),
              onChanged: onChanged,
              isTimerActive: isTimerActive,
              timerSecondsRemaining: isTimerActive ? activitySecondsRemaining : null,
              onStartTimer: (targetSeconds) => onStartActivityTimer(globalIndex, targetSeconds),
              onStopTimer: onStopActivityTimer,
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

class _SetRow extends StatelessWidget {
  final int setNumber;
  final _PendingSet pendingSet;
  final VoidCallback onRemove;
  final VoidCallback onToggleComplete;
  final VoidCallback onChanged;
  final bool isTimerActive;
  final int? timerSecondsRemaining;
  final void Function(int) onStartTimer;
  final VoidCallback onStopTimer;

  const _SetRow({
    required this.setNumber,
    required this.pendingSet,
    required this.onRemove,
    required this.onToggleComplete,
    required this.onChanged,
    required this.isTimerActive,
    required this.timerSecondsRemaining,
    required this.onStartTimer,
    required this.onStopTimer,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = pendingSet.isCompleted;

    return Opacity(
      opacity: isCompleted ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Completion checkbox
            Checkbox(
              value: isCompleted,
              onChanged: (_) => onToggleComplete(),
            ),
            // Set number
            SizedBox(
              width: 32,
              child: Text(
                '$setNumber',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            // Input fields
            Expanded(child: _buildInputFields(context, isCompleted)),
            // Delete button
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputFields(BuildContext context, bool disabled) {
    switch (pendingSet.exercise.type) {
      case ExerciseType.repetitionBased:
        return _RepsInput(
          value: pendingSet.repetitions,
          enabled: !disabled,
          onChanged: (value) {
            pendingSet.repetitions = value;
            onChanged();
          },
        );

      case ExerciseType.timeBased:
        return _ActivityTimerInput(
          targetSeconds: pendingSet.durationInSeconds,
          isRunning: isTimerActive,
          secondsRemaining: timerSecondsRemaining,
          enabled: !disabled,
          onTargetChanged: (value) {
            pendingSet.durationInSeconds = value;
            onChanged();
          },
          onStart: () {
            final target = pendingSet.durationInSeconds ?? 30;
            onStartTimer(target);
          },
          onStop: onStopTimer,
        );

      case ExerciseType.distanceBased:
        return _DistanceInput(
          value: pendingSet.distanceInMeters,
          enabled: !disabled,
          onChanged: (value) {
            pendingSet.distanceInMeters = value;
            onChanged();
          },
        );

      case ExerciseType.weightedRepetitions:
        return Row(
          children: [
            Expanded(
              child: _RepsInput(
                value: pendingSet.repetitions,
                enabled: !disabled,
                onChanged: (value) {
                  pendingSet.repetitions = value;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _WeightInput(
                value: pendingSet.weightInKilograms,
                enabled: !disabled,
                onChanged: (value) {
                  pendingSet.weightInKilograms = value;
                  onChanged();
                },
              ),
            ),
          ],
        );
    }
  }
}

class _RepsInput extends StatelessWidget {
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _RepsInput({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      decoration: const InputDecoration(
        labelText: 'Reps',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      enabled: enabled,
      keyboardType: TextInputType.number,
      onChanged: (text) => onChanged(int.tryParse(text)),
    );
  }
}

class _WeightInput extends StatelessWidget {
  final double? value;
  final bool enabled;
  final ValueChanged<double?> onChanged;

  const _WeightInput({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      decoration: const InputDecoration(
        labelText: 'kg',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (text) => onChanged(double.tryParse(text)),
    );
  }
}

class _ActivityTimerInput extends StatelessWidget {
  final int? targetSeconds;
  final bool isRunning;
  final int? secondsRemaining;
  final bool enabled;
  final ValueChanged<int?> onTargetChanged;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _ActivityTimerInput({
    required this.targetSeconds,
    required this.isRunning,
    required this.secondsRemaining,
    required this.enabled,
    required this.onTargetChanged,
    required this.onStart,
    required this.onStop,
  });

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displaySeconds = isRunning ? secondsRemaining! : (targetSeconds ?? 30);

    return Row(
      children: [
        // Timer display/input
        Expanded(
          child: isRunning
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary),
                    borderRadius: BorderRadius.circular(4),
                    color: colorScheme.primaryContainer.withAlpha(50),
                  ),
                  child: Text(
                    _formatTime(displaySeconds),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                  ),
                )
              : TextFormField(
                  initialValue: targetSeconds?.toString() ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Seconds',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  onChanged: (text) => onTargetChanged(int.tryParse(text)),
                ),
        ),
        const SizedBox(width: 8),
        // Play/Stop button
        IconButton.filled(
          onPressed: enabled ? (isRunning ? onStop : onStart) : null,
          icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
          style: IconButton.styleFrom(
            backgroundColor: isRunning ? colorScheme.error : colorScheme.primary,
            foregroundColor: isRunning ? colorScheme.onError : colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }
}

class _DistanceInput extends StatelessWidget {
  final double? value;
  final bool enabled;
  final ValueChanged<double?> onChanged;

  const _DistanceInput({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Display in km but store in meters
    final displayValue = value != null ? (value! / 1000).toStringAsFixed(2) : '';
    return TextFormField(
      initialValue: displayValue,
      decoration: const InputDecoration(
        labelText: 'km',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (text) {
        final km = double.tryParse(text);
        onChanged(km != null ? km * 1000 : null);
      },
    );
  }
}
