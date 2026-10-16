
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatelessWidget {
  final Widget nextScreen;

  const WelcomeScreen({
    super.key,
    required this.nextScreen,
  });

  Future<void> _finishOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('myspeak_onboarding_completed', true);

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => nextScreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF061A38);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _finishOnboarding(context),
                  child: const Text('Skip'),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Welcome to',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),

              const Text(
                'MySpeak',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3048CB),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Create voice reminders in your language '
                'and never miss what matters.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF56627A),
                ),
              ),

              const SizedBox(height: 28),

              const Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _FeatureTile(
                        icon: Icons.edit_note,
                        title: 'Write Your Reminder',
                        description:
                            'Type what you want to remember.',
                        color: Color(0xFFE3EDFF),
                        iconColor: Color(0xFF2456D3),
                      ),
                      _FeatureTile(
                        icon: Icons.translate,
                        title: 'Choose a Language',
                        description:
                            'Use English, Telugu or Hindi.',
                        color: Color(0xFFEEE5FF),
                        iconColor: Color(0xFF8044C8),
                      ),
                      _FeatureTile(
                        icon: Icons.access_time,
                        title: 'Set Date and Time',
                        description:
                            'Schedule one-time or repeating reminders.',
                        color: Color(0xFFDEF7F4),
                        iconColor: Color(0xFF178A85),
                      ),
                      _FeatureTile(
                        icon: Icons.volume_up_outlined,
                        title: 'Hear It Spoken',
                        description:
                            'Your phone announces reminders, '
                            'even when the app is closed.',
                        color: Color(0xFFFFF0DA),
                        iconColor: Color(0xFFC07B1C),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => _finishOnboarding(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2845C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Get Started  →',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color iconColor;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF596579),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
