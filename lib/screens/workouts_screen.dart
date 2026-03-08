import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dullgym/database/database_helper.dart';
import 'package:dullgym/models/models.dart';
import 'package:dullgym/screens/active_workout_screen.dart';
import 'package:dullgym/screens/edit_template_screen.dart';
import 'package:dullgym/screens/workout_detail_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  List<Workout> _workouts = [];
  List<WorkoutTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final workouts = await DatabaseHelper.instance.getAllWorkouts();
    final templates = await DatabaseHelper.instance.getAllWorkoutTemplates();
    setState(() {
      _workouts = workouts;
      _templates = templates;
      _isLoading = false;
    });
  }

  Future<void> _startWorkoutFromTemplate(WorkoutTemplate template) async {
    final templateSets = await DatabaseHelper.instance
        .getTemplateSetsForTemplate(template.id!);

    if (!mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveWorkoutScreen(templateSets: templateSets),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _startEmptyWorkout() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const ActiveWorkoutScreen(),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _createTemplate() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const EditTemplateScreen()),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _editTemplate(WorkoutTemplate template) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditTemplateScreen(existingTemplate: template),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _exportData() async {
    try {
      final file = await DatabaseHelper.instance.exportAllDataToCsv();
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'DullGym Export',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    }
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workout'),
        content: Text('Delete workout from ${DateFormat.yMMMd().format(workout.date)}?'),
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

    if (shouldDelete == true && workout.id != null) {
      await DatabaseHelper.instance.deleteWorkout(workout.id!);
      _loadData();
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportData,
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  _buildQuickStartSection(),
                  const Divider(),
                  _buildEmptyWorkoutButton(),
                  const Divider(),
                  _buildHistorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickStartSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Start',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // New Template card
                _buildNewTemplateCard(colorScheme),
                // Existing templates
                ..._templates.map((template) => _buildTemplateCard(template, colorScheme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewTemplateCard(ColorScheme colorScheme) {
    return SizedBox(
      width: 120,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outline.withAlpha(100),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: _createTemplate,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  size: 32,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'New Template',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(WorkoutTemplate template, ColorScheme colorScheme) {
    return SizedBox(
      width: 140,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _editTemplate(template),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  template.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: IconButton.filled(
                  onPressed: () => _startWorkoutFromTemplate(template),
                  icon: const Icon(Icons.play_arrow),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyWorkoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextButton.icon(
        onPressed: _startEmptyWorkout,
        icon: const Icon(Icons.add),
        label: const Text('Start empty workout'),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          if (_workouts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No workouts yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...(_workouts.map((workout) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat.yMMMd().format(workout.date)),
                  subtitle: Text(_formatDuration(workout.durationInSeconds)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteWorkout(workout),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutDetailScreen(workout: workout),
                      ),
                    );
                    _loadData();
                  },
                ))),
        ],
      ),
    );
  }
}
