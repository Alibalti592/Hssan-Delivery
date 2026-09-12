import 'package:flutter/material.dart';

import '../theme.dart';

/// Shown while [AuthController] restores a session on app start. Purely a
/// branded loading state — there is nothing to interact with here.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DH',
              style: TextStyle(
                color: Color(0xFFE8ECF2),
                fontSize: 56,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: -2,
                height: 1,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Delivery Hassen',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Aussi rapide que votre pensée',
              style: TextStyle(color: Color(0xFF9AA5B6), fontSize: 13),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(Color(0xFF6B7787)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
