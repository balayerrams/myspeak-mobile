import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _hasCompletedOnboarding(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Color(0xFF061A38),
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final nextScreen = snapshot.data!
              ? const CreateReminderScreen()
              : const WelcomeScreen(nextScreen: CreateReminderScreen());

          return SplashScreen(nextScreen: nextScreen);
        },
      ),
    );
  }
}

class CreateReminderScreen extends StatefulWidget {
  const CreateReminderScreen({super.key});

  @override
  State<CreateReminderScreen> createState() => _CreateReminderScreenState();
}

class _CreateReminderScreenState extends State<CreateReminderScreen>
    with WidgetsBindingObserver {
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
  List<Reminder> _cachedReminders = [];
  bool _remindersLoaded = false;
  String? _remindersLoadError;

  
void _resetReminderForm() {
  _messageController.clear();
  _translationController.clear();

  setState(() {
    _selectedTime = TimeOfDay.now();
    _selectedLanguage = 'English';
    _repeat = 'Daily';
    _playbackMode = 'Automatic Voice';
    _announcementCount = 1;

    _translatedMessage = null;
    _translationSourceMessage = null;
    _translationTargetLanguage = null;
  });
}

  Future<void> _reloadReminders() async {
    try {
      final reminders = await ReminderDatabase.instance.getReminders();
      if (!mounted) return;
      setState(() {
        _cachedReminders = reminders;
        _remindersLoaded = true;
        _remindersLoadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _remindersLoaded = true;
        _remindersLoadError = '$error';
      });
    }
  }

  DateTime? _todayOccurrence(Reminder reminder, DateTime now) {
    if (!reminder.enabled) return null;
    final today = DateTime(now.year, now.month, now.day);
    if (reminder.repeat == 'Once') {
      final ms = reminder.announcementCount > 0 ? reminder.scheduledAt : null;
      if (ms == null) return null; // Legacy Once reminders have unknown dates.
      final scheduled = DateTime.fromMillisecondsSinceEpoch(ms);
      if (scheduled.year != now.year ||
          scheduled.month != now.month ||
          scheduled.day != now.day) {
        return null;
      }
      return scheduled;
    }
    if (reminder.repeat == 'Weekdays' &&
        (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday)) {
      return null;
    }
    if (reminder.repeat != 'Daily' && reminder.repeat != 'Weekdays')
    {
      return null;
    }
    return DateTime(
      today.year,
      today.month,
      today.day,
      reminder.hour,
      reminder.minute,
    );
  }

  late DateTime _liveNow;
  Timer? _clockTimer;
  static const MethodChannel _reminderChannel = MethodChannel(
    'com.example.myspeak/reminders',
  );
  bool? _exactAlarmAllowed;
  bool _checkingAlarmPermission = false;

  Future<bool> _refreshExactAlarmPermission() async {
    if (_checkingAlarmPermission) return _exactAlarmAllowed == true;
    _checkingAlarmPermission = true;
    try {
      final allowed =
          await _reminderChannel.invokeMethod<bool>('canScheduleExactAlarms') ??
          false;
      if (mounted) setState(() => _exactAlarmAllowed = allowed);
      return allowed;
    } catch (error) {
      debugPrint('MySpeak: exact alarm permission check failed: $error');
      if (mounted) setState(() => _exactAlarmAllowed = false);
      return false;
    } finally {
      _checkingAlarmPermission = false;
    }
  }

  Future<void> _openAlarmPermissionSettings() async {
    try {
      await _reminderChannel.invokeMethod('openExactAlarmSettings');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open alarm settings: $error')),
      );
    }
  }

  Future<void> _showAlarmPermissionDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable Alarms & reminders'),
        content: const Text(
          'MySpeak needs permission to schedule voice reminders at the '
          'selected time. Enable Alarms & reminders in Android settings, '
          'then return to MySpeak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openAlarmPermissionSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _liveNow = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    _reloadReminders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshExactAlarmPermission();
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _liveNow = DateTime.now();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshExactAlarmPermission();
      _reloadReminders();
      setState(() {
        _liveNow = DateTime.now();
      });
    }
  }

  String _liveClock(BuildContext context) {
    final now = DateTime.now();

    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute:$second $period';
  }

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
      final response = await channel.invokeMethod<String>('scheduleTestAlarm');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response ?? 'Alarm scheduled')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alarm scheduling failed: $error')),
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
      final response = await channel.invokeMethod<String>('checkScheduler');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response ?? 'No response from Android')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Android bridge error: $error')));
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

    final response = await channel.invokeMethod<String>('scheduleReminder', {
      'reminderId': reminderId,
      'message': message,
      'speechMessage': speechMessage,
      'triggerTime': scheduledTime.millisecondsSinceEpoch,
      'repeat': repeat,
      'hour': hour,
      'minute': minute,
      'announcementCount': announcementCount,
      'language': language,
    });

    debugPrint('MySpeak scheduling response: $response');
  }

  Future<void> _saveReminder() async {
    final message = _messageController.text.trim();

    if (_isTranslating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for translation to finish')),
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

    final String? approvedSpeechMessage = _selectedLanguage == 'English'
        ? null
        : _translationController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder message')),
      );
      return;
    }

    // Do not create a database record if Android cannot schedule the alarm.
    if (!await _refreshExactAlarmPermission()) {
      await _showAlarmPermissionDialog();
      return;
    }
    if (!mounted) return;

    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    if (!scheduledTime.isAfter(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    if (_repeat == 'Weekdays') {
      while (scheduledTime.weekday == DateTime.saturday ||
          scheduledTime.weekday == DateTime.sunday) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
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
      scheduledAt: _repeat == 'Once'
          ? scheduledTime.millisecondsSinceEpoch
          : null,
    );

    try {
      final id = await ReminderDatabase.instance.insertReminder(reminder);

      if (_repeat == 'Once' || _repeat == 'Daily' || _repeat == 'Weekdays') {
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

          debugPrint('MySpeak: Reminder #$id scheduled for $scheduledTime');
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
        SnackBar(content: Text('Reminder #$id saved successfully!')),
      );

      _resetReminderForm();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save reminder: $error')),
      );
    }
  }

  Future<void> _translateMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder message')),
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

  Future<void> _previewVoice() async {
    final message = _messageController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder message')),
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
      final supported = await _flutterTts.isLanguageAvailable(languageCode);

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Voice preview failed: $error')));
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _flutterTts.stop();
    _messageController.dispose();
    super.dispose();
    _translationController.dispose();
  }

  static const _navy = Color(0xFF101F40);
  static const _accent = Color(0xFF5969CF);
  static const _gold = Color(0xFFF2B960);
  static const _background = Color(0xFFF5F7FC);

  Future<void> _openSaved() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SavedRemindersScreen()),
    );
    if (mounted) await _reloadReminders();
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 19, color: _accent),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
      ],
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8ECF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B102447),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _settingDropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<T> values,
    required String Function(T) text,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE7EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: _accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF67748B),
                  ),
                ),
              ),
            ],
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              style: const TextStyle(
                color: _navy,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              items: values
                  .map(
                    (v) => DropdownMenuItem<T>(
                      value: v,
                      child: Text(text(v), overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _navy,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.record_voice_over,
                      color: _gold,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MySpeak',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        Text(
                          'Your personal voice companion',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF77839A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Saved reminders',
                    onPressed: _openSaved,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: _navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: _accent),
                  const SizedBox(width: 7),
                  const Text(
                    'CURRENT TIME',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF748098),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _liveClock(context),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Good to have you here',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Make every important moment heard.',
                style: TextStyle(color: Color(0xFF748098)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10254B), Color(0xFF293E78)],
                  ),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: _gold, size: 19),
                        const SizedBox(width: 8),
                        const Text(
                          'NEXT REMINDER',
                          style: TextStyle(
                            letterSpacing: 1.3,
                            fontSize: 11,
                            color: Color(0xFFD7E2FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Refresh next reminder',
                          onPressed: _reloadReminders,
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    Builder(
                      builder: (context) {
                        if (!_remindersLoaded) {
                          return const Text(
                            'Loading reminders...',
                            style: TextStyle(color: Colors.white),
                          );
                        }
                        if (_remindersLoadError != null) {
                          return const Text(
                            'Unable to load reminders',
                            style: TextStyle(color: Colors.white),
                          );
                        }
                        final today = <(Reminder, DateTime)>[];
                        for (final reminder in _cachedReminders) {
                          final scheduled = _todayOccurrence(
                            reminder,
                            _liveNow,
                          );
                          if (scheduled != null)
                            {
                            today.add((reminder, scheduled));
                            }
                        }
                        today.sort((a, b) => a.$2.compareTo(b.$2));
                        final upcoming = today
                            .where((item) => item.$2.isAfter(_liveNow))
                            .toList();
                        final total = today.length;
                        final remaining = upcoming.length;
                        final passed = total - remaining;
                        final next = upcoming.isEmpty ? null : upcoming.first;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            if (next == null)
                              Text(
                                total == 0
                                    ? 'No reminders for today'
                                    : 'No reminders remaining today',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else ...[
                              Text(
                                TimeOfDay.fromDateTime(next.$2).format(context),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                next.$1.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFFE2E9FA),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _darkChip('Today'),
                                  _darkChip(next.$1.language),
                                  _darkChip(next.$1.repeat),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _dashboardMetric('Total today', total),
                                _dashboardMetric('Time passed', passed),
                                _dashboardMetric('Remaining', remaining),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: _openSaved,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('View all reminders'),
                      style: TextButton.styleFrom(
                        foregroundColor: _gold,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_exactAlarmAllowed == false) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4DE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alarms & reminders permission is off',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enable it so MySpeak can announce reminders on time.',
                      ),
                      TextButton.icon(
                        onPressed: _showAlarmPermissionDialog,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Enable permission'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _sectionTitle(Icons.add_circle_outline, 'Create a reminder'),
              if (_exactAlarmAllowed != true)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Enable Alarms & reminders permission to create reminders.',
                    style: TextStyle(color: Color(0xFF9C6222)),
                  ),
                ),
              const SizedBox(height: 12),
              IgnorePointer(
                ignoring: _exactAlarmAllowed != true,
                child: Opacity(
                  opacity: _exactAlarmAllowed == true ? 1 : 0.55,
                  child: _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'What would you like to hear?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _navy,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _messageController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'e.g. It is time for your medicine',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9AA5B6),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: _background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 17),
                        InkWell(
                          onTap: _selectTime,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  color: _accent,
                                  size: 27,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Reminder time',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF71809A),
                                        ),
                                      ),
                                      Text(
                                        _selectedTime.format(context),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: _navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.edit_outlined,
                                  color: _accent,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Voice preferences',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = (constraints.maxWidth - 10) / 2;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  width: width,
                                  child: _settingDropdown<String>(
                                    label: 'Language',
                                    icon: Icons.language,
                                    value: _selectedLanguage,
                                    values: const [
                                      'English',
                                      'Telugu',
                                      'Hindi',
                                    ],
                                    text: (v) => v,
                                    onChanged: (value) {
                                      if (value != null &&
                                          value != _selectedLanguage) {
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
                                ),
                                SizedBox(
                                  width: width,
                                  child: _settingDropdown<String>(
                                    label: 'Repeat',
                                    icon: Icons.repeat,
                                    value: _repeat,
                                    values: const ['Once', 'Daily', 'Weekdays'],
                                    text: (v) => v,
                                    onChanged: (v) {
                                      if (v != null)
                                      {
                                        setState(() => _repeat = v);
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: _settingDropdown<String>(
                                    label: 'Playback',
                                    icon: Icons.volume_up_outlined,
                                    value: _playbackMode,
                                    values: const [
                                      'Automatic Voice',
                                      'Notification First',
                                    ],
                                    text: (v) => v,
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _playbackMode = v);
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: _settingDropdown<int>(
                                    label: 'Announcements',
                                    icon: Icons.record_voice_over,
                                    value: _announcementCount,
                                    values: const [1, 2, 3, 4],
                                    text: (v) =>
                                        '$v ${v == 1 ? 'time' : 'times'}',
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _announcementCount = v);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (_selectedLanguage != 'English') ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _isTranslating
                                ? null
                                : _translateMessage,
                            icon: const Icon(Icons.translate),
                            label: Text(
                              _isTranslating
                                  ? 'Translating...'
                                  : 'Translate & Review',
                            ),
                          ),
                        ],
                        if (_translatedMessage != null &&
                            _selectedLanguage != 'English') ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _translationController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Translated reminder (editable)',
                              helperText:
                                  'Review the spoken text before saving',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: _previewVoice,
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Preview voice'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _exactAlarmAllowed == true
                              ? _saveReminder
                              : null,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Save reminder'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 20),
                ExpansionTile(
                  title: const Text(
                    'Developer tools',
                    style: TextStyle(color: Color(0xFF7C8798), fontSize: 13),
                  ),
                  children: [
                    ListTile(
                      title: const Text('Test Android bridge'),
                      onTap: _testAndroidBridge,
                    ),
                    ListTile(
                      title: const Text('Check exact alarm permission'),
                      onTap: _checkExactAlarmPermission,
                    ),
                    ListTile(
                      title: const Text('Schedule test alarm'),
                      onTap: _scheduleTestAlarm,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        selectedIndex: 0,
        indicatorColor: const Color(0xFFE9EDFF),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Reminders',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 1) _openSaved();
        },
      ),
    );
  }

  Widget _dashboardMetric(String label, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFFD7E2FF)),
        ),
      ],
    );
  }

  Widget _darkChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF40527C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
