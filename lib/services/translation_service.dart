
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:flutter/foundation.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._();

  TranslationService._();

  static const String _backendUrl = 'http://127.0.0.1:8000';

  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  TranslateLanguage _getLanguage(String language) {
    switch (language) {
      case 'Telugu':
        return TranslateLanguage.telugu;
      case 'Hindi':
        return TranslateLanguage.hindi;
      default:
        return TranslateLanguage.english;
    }
  }

  String _getLanguageCode(String language) {
    switch (language) {
      case 'Telugu':
        return 'te';
      case 'Hindi':
        return 'hi';
      case 'English':
        return 'en';
      default:
        throw ArgumentError('Unsupported language: $language');
    }
  }

  Future<String> translateReminder({
    required String message,
    required String targetLanguage,
  }) async {
    final originalMessage = message.trim();

    if (originalMessage.isEmpty) {
      throw ArgumentError('Reminder message cannot be empty');
    }

    final languageCode = _getLanguageCode(targetLanguage);

    if (languageCode == 'en') {
      return originalMessage;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/api/v1/translate/reminder'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': originalMessage,
              'source_language': 'en',
              'target_language': languageCode,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception(
          'Translation API returned ${response.statusCode}',
        );
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;

      final translated = data['translated_message'] as String?;

      if (translated == null || translated.trim().isEmpty) {
        throw StateError('Translation API returned an empty message');
      }

      debugPrint('MySpeak Translation Provider: GOOGLE_CLOUD');
      debugPrint('MySpeak Cloud Translation: $translated');
      return translated.trim();
    } catch (error) {
       debugPrint('MySpeak Translation Provider: ML_KIT_FALLBACK');
       debugPrint('MySpeak Cloud Translation Error: $error');
      return _translateOffline(
        message: originalMessage,
        targetLanguage: targetLanguage,
      );
    }
  }

  Future<String> _translateOffline({
    required String message,
    required String targetLanguage,
  }) async {
    final target = _getLanguage(targetLanguage);

    final translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: target,
    );

    try {
      final sourceModelAvailable =
          await _modelManager.isModelDownloaded('en');

      if (!sourceModelAvailable) {
        await _modelManager.downloadModel('en');
      }

      final targetModelAvailable =
          await _modelManager.isModelDownloaded(target.bcpCode);

      if (!targetModelAvailable) {
        await _modelManager.downloadModel(target.bcpCode);
      }

      final translated = await translator.translateText(message);

      if (translated.trim().isEmpty) {
        throw StateError('Offline translation returned an empty message');
      }

      return translated.trim();
    } finally {
      await translator.close();
    }
  }
}
