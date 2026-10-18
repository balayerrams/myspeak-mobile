
class Reminder {
  final int? id;
  final String message;
  final String? speechMessage;
  final int hour;
  final int minute;
  final String language;
  final String repeat;
  final String playbackMode;
  final int announcementCount;
  final bool enabled;
  final int? scheduledAt; // Epoch milliseconds; primarily for Once reminders
  

  Reminder({
    this.id,
    required this.message,
    this.speechMessage,
    required this.hour,
    required this.minute,
    required this.language,
    required this.repeat,
    required this.playbackMode,
    this.announcementCount = 1,
    this.enabled = true,
    this.scheduledAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'speech_message': speechMessage,
      'hour': hour,
      'minute': minute,
      'language': language,
      'repeat_type': repeat,
      'playback_mode': playbackMode,
      'announcement_count': announcementCount,
      'enabled': enabled ? 1 : 0,
      'scheduled_at': scheduledAt,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as int,
      message: map['message'] as String,
      speechMessage: map['speech_message'] as String?,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      language: map['language'] as String,
      repeat: map['repeat_type'] as String,
      playbackMode: map['playback_mode'] as String,
      announcementCount: (map['announcement_count'] as int?) ?? 1,
      enabled: (map['enabled'] as int) == 1,
      scheduledAt: map['scheduled_at'] as int?,
      
    );
  }
}
