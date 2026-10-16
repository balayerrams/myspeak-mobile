
class ReminderIntentService {
  /// Converts common reminder requests into concise actions.
  /// Preserves the original message elsewhere in the app.
  static String normalize(String message) {
    var normalized = message.trim();

    if (normalized.isEmpty) {
      return normalized;
    }

    // Remove common reminder prefixes only at the start.
    final prefixes = [
      RegExp(r'^please\s+remind\s+me\s+to\s+', caseSensitive: false),
      RegExp(r'^remind\s+me\s+to\s+', caseSensitive: false),
      RegExp(r'^please\s+remind\s+me\s+about\s+', caseSensitive: false),
      RegExp(r'^remind\s+me\s+about\s+', caseSensitive: false),
    ];

    for (final prefix in prefixes) {
      if (prefix.hasMatch(normalized)) {
        normalized = normalized.replaceFirst(prefix, '');
        break;
      }
    }

    return normalized.trim();
  }
}
