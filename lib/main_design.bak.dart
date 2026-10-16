import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
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
    const navy = Color(0xFF10254B);
    const accent = Color(0xFF52639B);
    const muted = Color(0xFF65718A);

    InputDecoration fieldDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: accent),
        filled: true,
        fillColor: const Color(0xFFF7F8FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE0E5F0)),
        ),
      );
    }

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w800,
        letterSpacing: 1.2, color: muted,
      )),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('MySpeak', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your reminders, spoken on time.',
                      style: TextStyle(color: Color(0xFFD8E4F6), fontSize: 13)),
                    SizedBox(height: 18),
                    Text('Create a Reminder', style: TextStyle(
                      color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('Never miss what matters.',
                      style: TextStyle(color: Color(0xFFD8E4F6), fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [BoxShadow(
                    color: Color(0x100E244D), blurRadius: 18, offset: Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sectionLabel('YOUR REMINDER'),
                    TextField(
                      controller: _messageController,
                      maxLines: 3,
                      decoration: fieldDecoration('Reminder Message', Icons.edit_note).copyWith(
                        hintText: 'Please take your morning medicine',
                      ),
                    ),
                    const SizedBox(height: 24),
                    sectionLabel('REMINDER TIME'),
                    Material(
                      color: const Color(0xFFF1F4FB),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _selectTime,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            const Icon(Icons.access_time_rounded, color: accent, size: 29),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedTime.format(context),
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: navy)),
                                const Text('Tap to change time',
                                  style: TextStyle(color: muted, fontSize: 12)),
                              ],
                            )),
                            const Icon(Icons.edit_outlined, color: accent),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    sectionLabel('PREFERENCES'),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLanguage,
                      isExpanded: true,
                      decoration: fieldDecoration('Voice Language', Icons.language),
                      items: ['English', 'Telugu', 'Hindi'].map((language) =>
                        DropdownMenuItem(value: language, child: Text(language))).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedLanguage = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _repeat,
                      isExpanded: true,
                      decoration: fieldDecoration('Repeat', Icons.repeat),
                      items: ['Once', 'Daily', 'Weekdays'].map((repeat) =>
                        DropdownMenuItem(value: repeat, child: Text(repeat))).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _repeat = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _playbackMode,
                      isExpanded: true,
                      decoration: fieldDecoration('Playback Mode', Icons.volume_up_outlined),
                      items: ['Automatic Voice', 'Notification First'].map((mode) =>
                        DropdownMenuItem(value: mode, child: Text(mode))).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _playbackMode = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      initialValue: _announcementCount,
                      isExpanded: true,
                      decoration: fieldDecoration('Announcement Iterations', Icons.record_voice_over_outlined)
                        .copyWith(helperText: 'Number of times to speak at each reminder'),
                      items: [1, 2, 3, 4].map((count) => DropdownMenuItem<int>(
                        value: count,
                        child: Text('$count ${count == 1 ? 'time' : 'times'}'),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _announcementCount = value);
                      },
                    ),
                    const SizedBox(height: 22),
                    if (_selectedLanguage != 'English') ...[
                      OutlinedButton.icon(
                        onPressed: _isTranslating ? null : _translateMessage,
                        icon: const Icon(Icons.translate),
                        label: Text(_isTranslating ? 'Translating...' : 'Translate & Preview'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_translatedMessage != null) ...[
                      TextField(
                        controller: _translationController,
                        maxLines: 3,
                        decoration: fieldDecoration('Translated Reminder (Editable)', Icons.translate)
                          .copyWith(helperText: 'Review and correct the translation before saving'),
                      ),
                      const SizedBox(height: 16),
                    ],
                    OutlinedButton.icon(
                      onPressed: _previewVoice,
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Preview Voice'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        foregroundColor: accent,
                        side: const BorderSide(color: accent),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _saveReminder,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Reminder'),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => const SavedRemindersScreen(),
                        ));
                      },
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('View Saved Reminders'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        foregroundColor: navy,
                      ),
                    ),
                  ],
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 18),
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.developer_mode),
                    title: const Text('Developer Tools'),
                    children: [
                      ListTile(title: const Text('Test Android Bridge'),
                        onTap: _testAndroidBridge),
                      ListTile(title: const Text('Check Exact Alarm Permission'),
                        onTap: _checkExactAlarmPermission),
                      ListTile(title: const Text('Schedule Test Alarm (2 Minutes)'),
                        onTap: _scheduleTestAlarm),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
