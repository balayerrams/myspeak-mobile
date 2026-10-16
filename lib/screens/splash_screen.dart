
import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => widget.nextScreen,
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061A38),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: Image.asset(
                  'assets/images/myspeak-icon.png',
                  width: 210,
                  height: 210,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'MySpeak',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Your reminders, spoken on time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFD7E6F7),
                ),
              ),

              const SizedBox(height: 48),

              const SizedBox(
                width: 130,
                child: LinearProgressIndicator(
                  minHeight: 4,
                  color: Color(0xFF35D6D0),
                  backgroundColor: Color(0xFF294366),
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB7C9DE),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
