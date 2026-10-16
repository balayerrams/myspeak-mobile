import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/translation_service.dart';
import '../services/reminder_database.dart';

import '../models/reminder.dart';

class EditReminderScreen extends StatefulWidget {
  final Reminder reminder;

  const EditReminderScreen({super.key, required this.reminder});

  @override
  State<EditReminderScreen> createState() => _EditReminderScreenState();
}

class _EditReminderScreenState extends State<EditReminderScreen> {
  late final TextEditingController _messageController;
  late final TextEditingController _speechController;
  final FlutterTts _tts = FlutterTts();
  bool _isTranslating = false;
  String? _approvedSource;
  String? _approvedLanguage;

  bool get _translationIsCurrent =>
      !_isTranslating &&
      _approvedSource == _messageController.text.trim() &&
      _approvedLanguage == _selectedLanguage &&
      _speechController.text.trim().isNotEmpty;

  void _onMessageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _translateForEdit() async {
    final source = _messageController.text.trim();
    final language = _selectedLanguage;
    if (source.isEmpty || language == 'English') return;
    setState(() {
      _isTranslating = true;
      _approvedSource = null;
      _approvedLanguage = null;
      _speechController.clear();
    });
    try {
      final translated = await TranslationService.instance.translateReminder(
        message: source,
        targetLanguage: language,
      );
      if (!mounted) return;
      // Discard stale async responses after source/language changes.
      if (_messageController.text.trim() != source ||
          _selectedLanguage != language) {
        return;
      }
      setState(() {
        _speechController.text = translated;
        _approvedSource = source;
        _approvedLanguage = language;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Translation failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  Future<void> _previewEditedVoice() async {
    final source = _messageController.text.trim();
    if (source.isEmpty) return;
    if (_selectedLanguage != 'English' && !_translationIsCurrent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translate and review the current reminder first'),
        ),
      );
      return;
    }
    final codes = {'English': 'en-IN', 'Telugu': 'te-IN', 'Hindi': 'hi-IN'};
    final code = codes[_selectedLanguage]!;
    try {
      if (await _tts.isLanguageAvailable(code) != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$_selectedLanguage voice is not installed on this phone',
            ),
          ),
        );
        return;
      }
      await _tts.setLanguage(code);
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.speak(
        _selectedLanguage == 'English' ? source : _speechController.text.trim(),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Voice preview failed: $error')));
    }
  }

  late TimeOfDay _selectedTime;
  late String _selectedLanguage;
  late String _repeat;
  late String _playbackMode;
  late int _announcementCount;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();

    final reminder = widget.reminder;

    _messageController = TextEditingController(text: reminder.message);

    _speechController = TextEditingController(
      text: reminder.speechMessage ?? '',
    );
    _messageController.addListener(_onMessageChanged);
    if (reminder.language != 'English' &&
        (reminder.speechMessage?.trim().isNotEmpty ?? false)) {
      _approvedSource = reminder.message.trim();
      _approvedLanguage = reminder.language;
    }

    _selectedTime = TimeOfDay(hour: reminder.hour, minute: reminder.minute);

    _selectedLanguage = reminder.language;
    _repeat = reminder.repeat;
    _playbackMode = reminder.playbackMode;
    _announcementCount = reminder.announcementCount;
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (selected != null) {
      setState(() {
        _selectedTime = selected;
      });
    }
  }

  Reminder _buildUpdatedReminder() {
    final original = widget.reminder;
    final message = _messageController.text.trim();

    return Reminder(
      id: original.id,
      message: message,
      speechMessage: _selectedLanguage == 'English'
          ? null
          : (_translationIsCurrent ? _speechController.text.trim() : null),
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      language: _selectedLanguage,
      repeat: _repeat,
      playbackMode: _playbackMode,
      announcementCount: _announcementCount,
      enabled: original.enabled,
    );
  }

  DateTime _calculateNextReminderTime(Reminder reminder) {
    final now = DateTime.now();

    var nextTime = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.hour,
      reminder.minute,
    );

    if (!nextTime.isAfter(now)) {
      nextTime = DateTime(
        now.year,
        now.month,
        now.day + 1,
        reminder.hour,
        reminder.minute,
      );
    }

    if (reminder.repeat == 'Weekdays') {
      while (nextTime.weekday == DateTime.saturday ||
          nextTime.weekday == DateTime.sunday) {
        nextTime = DateTime(
          nextTime.year,
          nextTime.month,
          nextTime.day + 1,
          reminder.hour,
          reminder.minute,
        );
      }
    }

    return nextTime;
  }

  Future<void> _updateReminder() async {
    if (_isUpdating) return;

    final updated = _buildUpdatedReminder();
    final reminderId = updated.id;

    if (updated.language != 'English' &&
        (updated.speechMessage == null ||
            updated.speechMessage!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please translate and review the current reminder before updating.',
          ),
        ),
      );
      return;
    }

    if (reminderId == null) return;

    if (updated.message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder message')),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    const channel = MethodChannel('com.example.myspeak/reminders');
    final original = widget.reminder;
    bool databaseUpdated = false;
    bool alarmChangeAttempted = false;

    Future<void> scheduleAlarm(Reminder reminder) async {
      final nextTime = _calculateNextReminderTime(reminder);

      await channel.invokeMethod<String>('scheduleReminder', {
        'reminderId': reminderId,
        'message': reminder.message,
        'speechMessage': reminder.speechMessage ?? reminder.message,
        'triggerTime': nextTime.millisecondsSinceEpoch,
        'repeat': reminder.repeat,
        'hour': reminder.hour,
        'minute': reminder.minute,
        'announcementCount': reminder.announcementCount,
        'language': reminder.language,
      });
    }

    try {
      final rows = await ReminderDatabase.instance.updateReminder(updated);
      if (rows != 1) {
        throw StateError('Reminder not found in database');
      }
      databaseUpdated = true;

      // The native call can fail after making a change, so track attempts.
      alarmChangeAttempted = true;
      await channel.invokeMethod<String>('cancelReminder', {
        'reminderId': reminderId,
      });

      if (updated.enabled) {
        await scheduleAlarm(updated);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder updated successfully')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      final recoveryErrors = <String>[];

      // Restore SQLite even if restoring the Android alarm fails.
      if (databaseUpdated) {
        try {
          final rows = await ReminderDatabase.instance.updateReminder(original);
          if (rows != 1) {
            throw StateError('Original reminder could not be restored');
          }
        } catch (restoreError) {
          recoveryErrors.add('Database: $restoreError');
        }
      }

      if (alarmChangeAttempted) {
        try {
          await channel.invokeMethod<String>('cancelReminder', {
            'reminderId': reminderId,
          });
          if (original.enabled) {
            await scheduleAlarm(original);
          }
        } catch (restoreError) {
          recoveryErrors.add('Android alarm: $restoreError');
        }
      }

      if (!mounted) return;
      final message = recoveryErrors.isEmpty
          ? 'Update failed; previous reminder settings were restored. '
                'Please verify the next alarm. Error: $error'
          : 'WARNING: Update failed and recovery was incomplete. '
                'Check this reminder before relying on it. '
                'Error: $error. Recovery: ${recoveryErrors.join('; ')}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _speechController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Reminder')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reminder Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Reminder Time'),
              subtitle: Text(_selectedTime.format(context)),
              trailing: const Icon(Icons.edit),
              onTap: _selectTime,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Voice Language',
                border: OutlineInputBorder(),
              ),
              items: ['English', 'Telugu', 'Hindi']
                  .map(
                    (language) => DropdownMenuItem(
                      value: language,
                      child: Text(language),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  if (value != _selectedLanguage) {
                    setState(() {
                      _selectedLanguage = value;
                      _approvedSource = null;
                      _approvedLanguage = null;
                      _speechController.clear();
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _repeat,
              decoration: const InputDecoration(
                labelText: 'Repeat',
                border: OutlineInputBorder(),
              ),
              items: ['Once', 'Daily', 'Weekdays']
                  .map(
                    (repeat) =>
                        DropdownMenuItem(value: repeat, child: Text(repeat)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _repeat = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _playbackMode,
              decoration: const InputDecoration(
                labelText: 'Playback Mode',
                border: OutlineInputBorder(),
              ),
              items: ['Automatic Voice', 'Notification First']
                  .map(
                    (mode) => DropdownMenuItem(value: mode, child: Text(mode)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _playbackMode = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _announcementCount,
              decoration: const InputDecoration(
                labelText: 'Announcement Iterations',
                helperText: 'Number of times to speak at each reminder',
                border: OutlineInputBorder(),
              ),
              items: [1, 2, 3, 4]
                  .map(
                    (count) => DropdownMenuItem<int>(
                      value: count,
                      child: Text('$count ${count == 1 ? 'time' : 'times'}'),
                    ),
                  )
                  .toList(),
              onChanged: _isUpdating
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _announcementCount = value);
                      }
                    },
            ),
            if (_selectedLanguage != 'English') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: (_isTranslating || _isUpdating)
                    ? null
                    : _translateForEdit,
                icon: const Icon(Icons.translate),
                label: Text(
                  _isTranslating ? 'Translating...' : 'Translate & Review',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _speechController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Spoken Reminder ($_selectedLanguage)',
                  helperText: _translationIsCurrent
                      ? 'Review or correct the spoken text'
                      : 'Translate the current message before updating',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isUpdating ? null : _previewEditedVoice,
              icon: const Icon(Icons.volume_up),
              label: const Text('Preview Voice'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isUpdating ? null : _updateReminder,
              icon: const Icon(Icons.save),
              label: const Text('Update Reminder'),
            ),
          ],
        ),
      ),
    );
  }
}
