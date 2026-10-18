
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/reminder.dart';

class ReminderDatabase {
  ReminderDatabase._();

  static final ReminderDatabase instance = ReminderDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'personal_voice_reminder.db');

    _database = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE reminders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          message TEXT NOT NULL,
          speech_message TEXT,
          hour INTEGER NOT NULL,
          minute INTEGER NOT NULL,
          language TEXT NOT NULL,
          repeat_type TEXT NOT NULL,
          playback_mode TEXT NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 1,
          announcement_count INTEGER NOT NULL DEFAULT 1,
          scheduled_at INTEGER
        )
      ''');

      },
      onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('''
          ALTER TABLE reminders
          ADD COLUMN announcement_count INTEGER NOT NULL DEFAULT 1
        ''');
      }

      if (oldVersion < 3) {
        await db.execute('''
          ALTER TABLE reminders
          ADD COLUMN speech_message TEXT
        ''');
      }

      if (oldVersion < 4) {
        await db.execute('ALTER TABLE reminders ADD COLUMN scheduled_at INTEGER');
      }
    },
    );

    return _database!;
  }

  Future<int> insertReminder(Reminder reminder) async {
    final db = await database;

    return db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  
Future<int> updateReminderEnabled(
  int reminderId,
  bool enabled,
) async {
  final db = await database;

  return await db.update(
    'reminders',
    {
      'enabled': enabled ? 1 : 0,
    },
    where: 'id = ?',
    whereArgs: [reminderId],
  );
}


Future<int> updateReminder(Reminder reminder) async {
  final db = await database;

  if (reminder.id == null) {
    throw ArgumentError('Reminder ID is required for update');
  }

  return await db.update(
    'reminders',
    {
      'message': reminder.message,
      'speech_message': reminder.speechMessage,
      'hour': reminder.hour,
      'minute': reminder.minute,
      'language': reminder.language,
      'repeat_type': reminder.repeat,
      'playback_mode': reminder.playbackMode,
      'enabled': reminder.enabled ? 1 : 0,
      'announcement_count': reminder.announcementCount,
      'scheduled_at': reminder.scheduledAt,
    },
    where: 'id = ?',
    whereArgs: [reminder.id],
  );
}


Future<int> deleteReminder(int reminderId) async {
  final db = await database;

  return await db.delete(
    'reminders',
    where: 'id = ?',
    whereArgs: [reminderId],
  );
}



  Future<List<Reminder>> getReminders() async {
    final db = await database;

    final records = await db.query(
      'reminders',
      orderBy: 'hour ASC, minute ASC',
    );

    return records.map(Reminder.fromMap).toList();
  }
}
