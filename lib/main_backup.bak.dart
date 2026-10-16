import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'models/reminder.dart';
import 'services/reminder_database.dart';
import 'screens/saved_reminders_screen.dart';
import 'package:flutter/services.dart';
import 'services/translation_service.dart';
import 'services/reminder_intent_service.dart';
import 'screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const PersonalVoiceReminderApp());
}


class PersonalVoiceReminderApp extends StatelessWidget {
  const PersonalVoiceReminderApp({super.key});

  Future<bool> _hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('myspeak_onboarding_completed') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MySpeak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _hasCompletedOnboarding(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Color(0xFF061A38),
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final nextScreen = snapshot.data!
              ? const CreateReminderScreen()
              : const WelcomeScreen(
                  nextScreen: CreateReminderScreen(),
                );

          return SplashScreen(
            nextScreen: nextScreen,
          );
        },
      ),
    );
  }
}


class CreateReminderScreen extends StatefulWidget {
  const CreateReminderScreen({super.key});

  @override
  State<CreateReminderScreen> createState() =>
      _CreateReminderScreenState();
}

class _CreateReminderScreenState extends State<CreateReminderScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _translationController = TextEditingController();

  final FlutterTts _flutterTts = FlutterTts();
  
  bool get _hasValidTranslation {
    return !_isTranslating &&
        _translatedMessage != null &&
        _translationController.text.trim().isNotEmpty &&
        _translationSourceMessage == _messageController.text.trim() &&
        _translationTargetLanguage == _selectedLanguage;
  }

  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedLanguage = 'English';
  String _repeat = 'Daily';
  String _playbackMode = 'Automatic Voice';
  int _announcementCount = 1;
  String? _translatedMessage;
 bool _isTranslating = false;
 String? _translationSourceMessage;
String? _translationTargetLanguage;

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (selected != null) {
      setState(() => _selectedTime = selected);
    }
  }

Future<void> _scheduleTestAlarm() async {
  const channel = MethodChannel('com.example.myspeak/reminders');

  try {
    final response =
        await channel.invokeMethod<String>('scheduleTestAlarm');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response ?? 'Alarm scheduled'),
      ),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Alarm scheduling failed: $error'),
      ),
    );
  }
}

Future<void> _checkExactAlarmPermission() async {
  const channel = MethodChannel('com.example.myspeak/reminders');

  try {
    final bool allowed =
        await channel.invokeMethod<bool>('canScheduleExactAlarms') ?? false;

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allowed
              ? 'Exact Alarm Permission: ALLOWED'
              : 'Exact Alarm Permission: NOT ALLOWED',
        ),
      ),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Permission check failed: $error')),
    );
  }
}


Future<void> _testAndroidBridge() async {
  const channel = MethodChannel('com.example.myspeak/reminders');

  try {
    final response =
        await channel.invokeMethod<String>('checkScheduler');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response ?? 'No response from Android'),
      ),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Android bridge error: $error'),
      ),
    );
  }
}


// Additional methods for scheduling reminders, saving reminders, and previewing voice will be added here.
Future<void> _scheduleSavedReminder({
  required int reminderId,
  required String message,
  required String speechMessage,
  required DateTime scheduledTime,
   required String repeat,
   required int hour,
  required int minute,
  required int announcementCount,
  required String language,
}) async {
  const channel = MethodChannel('com.example.myspeak/reminders');

  final response = await channel.invokeMethod<String>(
    'scheduleReminder',
    {
      'reminderId': reminderId,
      'message': message,
      'speechMessage': speechMessage,
      'triggerTime': scheduledTime.millisecondsSinceEpoch,
      'repeat': repeat,
      'hour': hour,
      'minute': minute,
      'announcementCount': announcementCount,
      'language': language,
    },
  );

  debugPrint('MySpeak scheduling response: $response');
}

  
Future<void> _saveReminder() async {
  final message = _messageController.text.trim();
  
  if (_isTranslating) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Please wait for translation to finish'),
    ),
  );
  return;
}

if (_selectedLanguage != 'English' && !_hasValidTranslation) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Please translate and review the reminder before saving',
      ),
    ),
  );
  return;
}

final String? approvedSpeechMessage =
    _selectedLanguage == 'English'
        ? null
        : _translationController.text.trim();

  if (message.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter a reminder message'),
      ),
    );
    return;
  }

  final reminder = Reminder(
    message: message,
    speechMessage: approvedSpeechMessage,
    hour: _selectedTime.hour,
    minute: _selectedTime.minute,
    language: _selectedLanguage,
    repeat: _repeat,
    playbackMode: _playbackMode,
    announcementCount: _announcementCount,
    
  );

  try {
    final id = await ReminderDatabase.instance.insertReminder(reminder);

    
if (_repeat == 'Once' || _repeat == 'Daily' || _repeat == 'Weekdays') {
  final now = DateTime.now();

  var scheduledTime = DateTime(
    now.year,
    now.month,
    now.day,
    _selectedTime.hour,
    _selectedTime.minute,
  );

  // A one-time reminder must be scheduled in the future.
  // If today's selected time has passed, use tomorrow.
  if (!scheduledTime.isAfter(now)) {
    scheduledTime = scheduledTime.add(
      const Duration(days: 1),
    );
  }
  if (_repeat == 'Weekdays') {
    while (scheduledTime.weekday == DateTime.saturday ||
        scheduledTime.weekday == DateTime.sunday) {
      scheduledTime = scheduledTime.add(
        const Duration(days: 1),
      );
    }
  }

  try {
    await _scheduleSavedReminder(
      reminderId: id,
      message: message,
      speechMessage: approvedSpeechMessage ?? message,
      scheduledTime: scheduledTime,
      repeat: _repeat,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      announcementCount: _announcementCount,
      language: _selectedLanguage,
    );

    debugPrint(
      'MySpeak: Reminder #$id scheduled for $scheduledTime',
    );
  } catch (error) {
    debugPrint(
      'MySpeak: Reminder #$id saved but scheduling failed: $error',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder saved, but Android scheduling failed: $error',
        ),
      ),
    );

    return;
  }
}


    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reminder #$id saved successfully!'),
      ),
    );

    _messageController.clear();
    _translationController.clear();

    setState(() {
      _translatedMessage = null;
      _translationSourceMessage = null;
      _translationTargetLanguage = null;
  });
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to save reminder: $error'),
      ),
    );
  }
}

Future<void> _translateMessage() async {
  final message = _messageController.text.trim();

  if (message.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter a reminder message'),
      ),
    );
    return;
  }

      setState(() {
      _isTranslating = true;
      _translatedMessage = null;
      _translationSourceMessage = null;
      _translationTargetLanguage = null;
    });

  try {
    final normalizedMessage = ReminderIntentService.normalize(message);

    final translated = await TranslationService.instance.translateReminder(
      message: normalizedMessage,
      targetLanguage: _selectedLanguage,
    );

    if (!mounted) return;
    _translationController.text = translated;
    setState(() {
      _translatedMessage = translated;
      _translationSourceMessage = message;
      _translationTargetLanguage = _selectedLanguage;
    });
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Translation failed: $error'),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isTranslating = false;
      });
    }
  }
}



Future<void> _previewVoice() async {
  final message = _messageController.text.trim();

  if (message.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter a reminder message'),
      ),
    );
    return;
  }

  final languageCodes = {
    'English': 'en-IN',
    'Telugu': 'te-IN',
    'Hindi': 'hi-IN',
  };

  final languageCode = languageCodes[_selectedLanguage] ?? 'en-IN';

  // Declare speechText before using it in any condition.
  String speechText = message;

  if (_selectedLanguage != 'English') {
    if (!_hasValidTranslation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please translate and review the reminder before previewing',
          ),
        ),
      );
      return;
    }

    speechText = _translationController.text.trim();
  }

  try {
    final supported =
        await _flutterTts.isLanguageAvailable(languageCode);

    if (supported != true) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Voice for $_selectedLanguage is not available. '
            'Install it in Android Text-to-Speech settings.',
          ),
        ),
      );
      return;
    }

    await _flutterTts.setLanguage(languageCode);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(speechText);
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voice preview failed: $error'),
      ),
    );
  }
}




  @override
  void dispose() {
     _flutterTts.stop();
    _messageController.dispose();
    super.dispose();
    _translationController.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Voice Reminder'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.record_voice_over,
                size: 64,
                color: Colors.indigo,
              ),
              const SizedBox(height: 12),
              const Text(
                'Create Voice Reminder',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reminder Message',
                  hintText: 'Please take your morning medicine',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Reminder Time'),
                  subtitle: Text(_selectedTime.format(context)),
                  trailing: const Icon(Icons.edit),
                  onTap: _selectTime,
                ),
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
                if (value != null && value != _selectedLanguage) {
                  setState(() {
                    _selectedLanguage = value;
                    _translatedMessage = null;
                    _translationSourceMessage = null;
                    _translationTargetLanguage = null;
                    _translationController.clear();
                  });
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
                      (repeat) => DropdownMenuItem(
                        value: repeat,
                        child: Text(repeat),
                      ),
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
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode),
                      ),
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
  onChanged: (value) {
    if (value != null) {
      setState(() => _announcementCount = value);
    }
  },
),

              const SizedBox(height: 24),

              if (_selectedLanguage != 'English')
              OutlinedButton.icon(
                onPressed: _isTranslating ? null : _translateMessage,
                icon: const Icon(Icons.translate),
                label: Text(
                  _isTranslating ? 'Translating...' : 'Translate & Preview',
                ),
              ),

              if (_translatedMessage != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _translationController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Translated Reminder (Editable)',
                  helperText: 'Review and correct the translation before saving',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

              OutlinedButton.icon(
                onPressed: _previewVoice,
                icon: const Icon(Icons.volume_up),
                label: const Text('Preview Voice'),
              ),

              ElevatedButton.icon(
              onPressed: _testAndroidBridge,
              icon: const Icon(Icons.settings_remote),
              label: const Text('Test Android Bridge'),
            ),

            ElevatedButton.icon(
            onPressed: _checkExactAlarmPermission,
            icon: const Icon(Icons.alarm),
            label: const Text('Check Exact Alarm Permission'),
          ),

          ElevatedButton.icon(
            onPressed: _scheduleTestAlarm,
            icon: const Icon(Icons.notifications_active),
            label: const Text('Schedule Test Alarm (2 Minutes)'),
          ),

              const SizedBox(height: 12),

              FilledButton.icon(
                onPressed: _saveReminder,
                icon: const Icon(Icons.save),
                label: const Text('Save Reminder'),
              ),
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedRemindersScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: const Text('View Saved Reminders'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
