import 'package:flutter/material.dart';

const String _appVersion = '1.0.0';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003B74),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Spacer(),
            Image.asset('assets/splash.png', width: 120),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text('v$_appVersion', style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
