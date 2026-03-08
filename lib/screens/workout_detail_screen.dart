import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dullgym/database/database_helper.dart';
import 'package:dullgym/models/models.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  List<WorkoutSet> _sets = [];
  Map<int, Exercise> _exerciseMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkoutDetails();
  }

  Future<void> _loadWorkoutDetails() async {
    final workoutId = widget.workout.id;
    if (workoutId == null) {
      throw StateError('Cannot load details for workout without id');
    }

    final sets = await DatabaseHelper.instance.getWorkoutSetsForWorkout(workoutId);
    final exercises = await DatabaseHelper.instance.getAllExercises();

    setState(() {
      _sets = sets;
      _exerciseMap = {for (final exercise in exercises) exercise.id!: exercise};
      _isLoading = false;
    });
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatSetDetails(WorkoutSet set, Exercise? exercise) {
    if (exercise == null) return 'Unknown exercise';

    switch (exercise.type) {
      case ExerciseType.repetitionBased:
        return '${set.repetitions ?? 0} reps';
      case ExerciseType.timeBased:
        return '${set.durationInSeconds ?? 0} seconds';
      case ExerciseType.weightedRepetitions:
        return '${set.repetitions ?? 0} reps × ${set.weightInKilograms ?? 0} kg';
      case ExerciseType.distanceBased:
        final km = (set.distanceInMeters ?? 0) / 1000;
        return '${km.toStringAsFixed(2)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMd().format(widget.workout.date)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: 8),
                      Text(
                        'Duration: ${_formatDuration(widget.workout.durationInSeconds)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                if (widget.workout.notes != null && widget.workout.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(widget.workout.notes!),
                  ),
                const Divider(),
                Expanded(
                  child: _sets.isEmpty
                      ? const Center(child: Text('No sets recorded'))
                      : ListView.builder(
                          itemCount: _sets.length,
                          itemBuilder: (context, index) {
                            final set = _sets[index];
                            final exercise = _exerciseMap[set.exerciseId];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text('${set.setOrder}'),
                              ),
                              title: Text(exercise?.name ?? 'Unknown'),
                              subtitle: Text(_formatSetDetails(set, exercise)),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
