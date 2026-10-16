
class ReminderTerminologyService {
  static const Map<String, String> teluguTerms = {
    'breakfast': 'అల్పాహారం',
    'lunch': 'మధ్యాహ్న భోజనం',
    'dinner': 'రాత్రి భోజనం',
    'morning': 'ఉదయం',
    'afternoon': 'మధ్యాహ్నం',
    'evening': 'సాయంత్రం',
    'night': 'రాత్రి',
  };

  static const Map<String, String> hindiTerms = {
    'breakfast': 'नाश्ता',
    'lunch': 'दोपहर का भोजन',
    'dinner': 'रात का खाना',
    'morning': 'सुबह',
    'afternoon': 'दोपहर',
    'evening': 'शाम',
    'night': 'रात',
  };

  static Map<String, String> getTerms(String language) {
    switch (language) {
      case 'Telugu':
        return teluguTerms;
      case 'Hindi':
        return hindiTerms;
      default:
        return {};
    }
  }

  static List<String> findTerms({
    required String message,
    required String language,
  }) {
    final terms = getTerms(language);

    return terms.keys.where((term) {
      final expression = RegExp(
        '\\b${RegExp.escape(term)}\\b',
        caseSensitive: false,
      );

      return expression.hasMatch(message);
    }).toList();
  }
}
