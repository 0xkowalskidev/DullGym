import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dullgym/database/database_helper.dart';
import 'package:dullgym/models/models.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<Workout> _workouts = [];
  List<Exercise> _exercises = [];
  Exercise? _selectedExercise;
  List<_ExerciseProgressPoint> _progressData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final workouts = await DatabaseHelper.instance.getAllWorkouts();
    final exercises = await DatabaseHelper.instance.getAllExercises();

    setState(() {
      _workouts = workouts;
      _exercises = exercises;
      _isLoading = false;
    });
  }

  Future<void> _loadExerciseProgress(Exercise exercise) async {
    final sets = await DatabaseHelper.instance.getWorkoutSetsForExercise(exercise.id!);

    final Map<int, Workout> workoutMap = {
      for (final workout in _workouts) workout.id!: workout
    };

    final progressPoints = <_ExerciseProgressPoint>[];

    for (final set in sets) {
      final workout = workoutMap[set.workoutId];
      if (workout == null) continue;

      double value;
      switch (exercise.type) {
        case ExerciseType.repetitionBased:
          value = (set.repetitions ?? 0).toDouble();
          break;
        case ExerciseType.timeBased:
          value = (set.durationInSeconds ?? 0).toDouble();
          break;
        case ExerciseType.weightedRepetitions:
          value = (set.weightInKilograms ?? 0) * (set.repetitions ?? 0);
          break;
        case ExerciseType.distanceBased:
          value = (set.distanceInMeters ?? 0) / 1000; // Display as km
          break;
      }

      progressPoints.add(_ExerciseProgressPoint(date: workout.date, value: value));
    }

    progressPoints.sort((a, b) => a.date.compareTo(b.date));

    setState(() {
      _selectedExercise = exercise;
      _progressData = progressPoints;
    });
  }

  String _getValueLabel(Exercise exercise) {
    switch (exercise.type) {
      case ExerciseType.repetitionBased:
        return 'Reps';
      case ExerciseType.timeBased:
        return 'Duration (s)';
      case ExerciseType.weightedRepetitions:
        return 'Volume (kg × reps)';
      case ExerciseType.distanceBased:
        return 'Distance (km)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workouts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bar_chart,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No data yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text('Complete some workouts to see progress'),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<Exercise>(
                        initialValue: _selectedExercise,
                        decoration: const InputDecoration(
                          labelText: 'Select Exercise',
                          border: OutlineInputBorder(),
                        ),
                        items: _exercises.map((exercise) {
                          return DropdownMenuItem(
                            value: exercise,
                            child: Text(exercise.name),
                          );
                        }).toList(),
                        onChanged: (exercise) {
                          if (exercise != null) {
                            _loadExerciseProgress(exercise);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: _selectedExercise == null
                          ? const Center(child: Text('Select an exercise to view progress'))
                          : _progressData.isEmpty
                              ? const Center(child: Text('No data for this exercise'))
                              : Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _ProgressChart(
                                    data: _progressData,
                                    valueLabel: _getValueLabel(_selectedExercise!),
                                  ),
                                ),
                    ),
                  ],
                ),
    );
  }
}

class _ExerciseProgressPoint {
  final DateTime date;
  final double value;

  _ExerciseProgressPoint({required this.date, required this.value});
}

class _ProgressChart extends StatelessWidget {
  final List<_ExerciseProgressPoint> data;
  final String valueLabel;

  const _ProgressChart({required this.data, required this.valueLabel});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    final maxY = data.map((point) => point.value).reduce((a, b) => a > b ? a : b);
    final minY = data.map((point) => point.value).reduce((a, b) => a < b ? a : b);
    final yRange = maxY - minY;
    final yPadding = yRange * 0.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valueLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 50),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox.shrink();
                      }
                      if (data.length > 7 && index % (data.length ~/ 5) != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat.MMMd().format(data[index].date),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: true),
              minY: (minY - yPadding).clamp(0, double.infinity),
              maxY: maxY + yPadding,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: data.length < 20,
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).colorScheme.primary.withAlpha(50),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      if (index < 0 || index >= data.length) return null;
                      final point = data[index];
                      return LineTooltipItem(
                        '${DateFormat.MMMd().format(point.date)}\n${point.value.toStringAsFixed(1)}',
                        TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
