
import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/reminder_database.dart';
import 'package:flutter/services.dart';
import 'edit_reminder_screen.dart';

class SavedRemindersScreen extends StatefulWidget {
  const SavedRemindersScreen({super.key});

  @override
  State<SavedRemindersScreen> createState() =>
      _SavedRemindersScreenState();
}

class _SavedRemindersScreenState extends State<SavedRemindersScreen> {
  late Future<List<Reminder>> _reminders;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  void _loadReminders() {
    _reminders = ReminderDatabase.instance.getReminders();
  }

  
Future<void> _disableReminder(Reminder reminder) async {
  final reminderId = reminder.id;

  if (reminderId == null) return;

  const channel = MethodChannel('com.example.myspeak/reminders');

  try {
    // Cancel the scheduled Android alarm first.
    await channel.invokeMethod<String>(
      'cancelReminder',
      {'reminderId': reminderId},
    );

    // Update SQLite only after cancellation succeeds.
    final updatedRows =
        await ReminderDatabase.instance.updateReminderEnabled(
      reminderId,
      false,
    );

    if (updatedRows != 1) {
      throw StateError('Reminder not found in database');
    }

    if (!mounted) return;

    setState(() {
      _loadReminders();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder disabled successfully')),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to disable reminder: $error')),
    );
  }
}

// Calculates the next scheduled time for a reminder based on its repeat type.
DateTime _calculateNextReminderTime(Reminder reminder) {
  final now = DateTime.now();

  var scheduledTime = DateTime(
    now.year,
    now.month,
    now.day,
    reminder.hour,
    reminder.minute,
  );

  // Move to tomorrow if today's scheduled time has passed.
  if (!scheduledTime.isAfter(now)) {
    scheduledTime = scheduledTime.add(
      const Duration(days: 1),
    );
  }

  // Weekdays reminders must skip Saturday and Sunday.
  if (reminder.repeat == 'Weekdays') {
    while (scheduledTime.weekday == DateTime.saturday ||
        scheduledTime.weekday == DateTime.sunday) {
      scheduledTime = scheduledTime.add(
        const Duration(days: 1),
      );
    }
  }

  return scheduledTime;
}


Future<void> _enableReminder(Reminder reminder) async {
  final reminderId = reminder.id;

  if (reminderId == null) return;

  const channel = MethodChannel('com.example.myspeak/reminders');

  try {
    final scheduledTime = _calculateNextReminderTime(reminder);

    // Schedule the reminder with Android.
    await channel.invokeMethod<String>(
      'scheduleReminder',
      {
        'reminderId': reminderId,
        'message': reminder.message,
        'speechMessage': reminder.speechMessage ?? reminder.message,
        'triggerTime': scheduledTime.millisecondsSinceEpoch,
        'repeat': reminder.repeat,
        'hour': reminder.hour,
        'minute': reminder.minute,
        'announcementCount': reminder.announcementCount,
        'language': reminder.language,
      },
    );

    // Update SQLite after successful scheduling.
    final updatedRows =
        await ReminderDatabase.instance.updateReminderEnabled(
      reminderId,
      true,
    );

    if (updatedRows != 1) {
      // Roll back the newly scheduled alarm.
      await channel.invokeMethod<String>(
        'cancelReminder',
        {'reminderId': reminderId},
      );
      throw StateError('Reminder not found in database');
    }

    if (!mounted) return;

    setState(() {
      _loadReminders();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder enabled for '
          '${scheduledTime.day}/${scheduledTime.month} '
          'at ${TimeOfDay(
            hour: reminder.hour,
            minute: reminder.minute,
          ).format(context)}',
        ),
      ),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to enable reminder: $error')),
    );
  }
}


  String _formatTime(Reminder reminder) {
    final hour = reminder.hour % 12 == 0 ? 12 : reminder.hour % 12;
    final minute = reminder.minute.toString().padLeft(2, '0');
    final period = reminder.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  
Future<void> _confirmDeleteReminder(Reminder reminder) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Reminder?'),
      content: Text(
        'Are you sure you want to delete "${reminder.message}"?\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !mounted) return;

  // Actual deletion will be implemented in Step 6.3.3.
  // For now, just show a snackbar to indicate the action.
  await _deleteReminder(reminder);
}


Future<void> _deleteReminder(Reminder reminder) async {
  final reminderId = reminder.id;

  if (reminderId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to delete: Reminder ID is missing'),
      ),
    );
    return;
  }

  const channel = MethodChannel('com.example.myspeak/reminders');

  try {
    // First cancel the scheduled Android alarm.
    await channel.invokeMethod<String>(
      'cancelReminder',
      {'reminderId': reminderId},
    );

    // Then remove the reminder from SQLite.
    final deletedRows =
        await ReminderDatabase.instance.deleteReminder(reminderId);

    if (deletedRows != 1) {
      throw StateError('Reminder not found in database');
    }

    if (!mounted) return;

    setState(() {
      _loadReminders();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reminder deleted successfully'),
      ),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to delete reminder: $error'),
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Reminders'),
      ),
      body: FutureBuilder<List<Reminder>>(
        future: _reminders,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load reminders: ${snapshot.error}'),
            );
          }

          final reminders = snapshot.data ?? [];

          if (reminders.isEmpty) {
            return const Center(
              child: Text('No reminders saved yet.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminders[index];

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: Text(reminder.message),
                  subtitle: Text(
                    '${_formatTime(reminder)}\n'
                    '${reminder.repeat} • ${reminder.language}\n'
                    '${reminder.playbackMode}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit Reminder',
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditReminderScreen(
                                reminder: reminder,
                              ),
                            ),
                          );

                          if (!mounted) return;

                          setState(() {
                            _loadReminders();
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red,
                        tooltip: 'Delete Reminder',
                        onPressed: () => _confirmDeleteReminder(reminder),
                      ),
                      Switch(
                        value: reminder.enabled,
                        onChanged: (bool enabled) {
                          if (enabled) {
                            _enableReminder(reminder);
                          } else {
                            _disableReminder(reminder);
                          }
                        },
                      ),
                    ],
                  ),

                ),
              );
            },
          );
        },
      ),
    );
  }
}
