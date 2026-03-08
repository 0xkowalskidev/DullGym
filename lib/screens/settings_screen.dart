import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dullgym/database/database_helper.dart';

const String defaultRestTimerSecondsKey = 'defaultRestTimerSeconds';
const int defaultRestTimerSecondsDefault = 60;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _defaultRestTimerSeconds = defaultRestTimerSecondsDefault;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultRestTimerSeconds = prefs.getInt(defaultRestTimerSecondsKey) ?? defaultRestTimerSecondsDefault;
      _isLoading = false;
    });
  }

  Future<void> _saveRestTimerSetting(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(defaultRestTimerSecondsKey, seconds);
    setState(() {
      _defaultRestTimerSeconds = seconds;
    });
  }

  Future<void> _showRestTimerDialog() async {
    int tempValue = _defaultRestTimerSeconds;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Default Rest Timer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${tempValue ~/ 60}:${(tempValue % 60).toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: tempValue > 15
                        ? () => setDialogState(() => tempValue = (tempValue - 15).clamp(15, 300))
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 8),
                  Text('${tempValue}s'),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: tempValue < 300
                        ? () => setDialogState(() => tempValue = (tempValue + 15).clamp(15, 300))
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: tempValue.toDouble(),
                min: 15,
                max: 300,
                divisions: 19,
                label: '${tempValue}s',
                onChanged: (value) {
                  setDialogState(() => tempValue = value.round());
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, tempValue),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _saveRestTimerSetting(result);
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

  Future<void> _importData() async {
    // Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file')),
      );
      return;
    }

    // Ask user: replace or merge?
    if (!mounted) return;
    final importMode = await showDialog<_ImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Mode'),
        content: const Text('How should the imported data be handled?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ImportMode.merge),
            child: const Text('Merge'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ImportMode.replace),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );

    if (importMode == null) return;

    // Confirm if replacing
    if (importMode == _ImportMode.replace) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace All Data?'),
          content: const Text(
            'This will delete all existing workouts, exercises, and templates. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final importResult = await DatabaseHelper.instance.importFromCsv(
        file.path!,
        replaceExisting: importMode == _ImportMode.replace,
      );

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${importResult.exercisesImported} exercises, '
            '${importResult.templatesImported} templates, '
            '${importResult.workoutsImported} workouts, '
            '${importResult.setsImported} sets.'
            '${importResult.rowsSkipped > 0 ? ' ${importResult.rowsSkipped} rows skipped.' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $error')),
      );
    }
  }

  String _formatRestTimer(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0 && secs > 0) {
      return '$minutes min $secs sec';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '$secs sec';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('Workout'),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Default Rest Timer'),
                  subtitle: Text(_formatRestTimer(_defaultRestTimerSeconds)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showRestTimerDialog,
                ),
                const Divider(),
                _buildSectionHeader('Data'),
                ListTile(
                  leading: const Icon(Icons.file_upload),
                  title: const Text('Export to CSV'),
                  subtitle: const Text('Save all workout data'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportData,
                ),
                ListTile(
                  leading: const Icon(Icons.file_download),
                  title: const Text('Import from CSV'),
                  subtitle: const Text('Load workout data from file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _importData,
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

enum _ImportMode { replace, merge }
