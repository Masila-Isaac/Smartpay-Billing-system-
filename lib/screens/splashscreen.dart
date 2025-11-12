import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Delay for 6 seconds then go to GetStarted screen
    Timer(const Duration(seconds: 6), () {
      Navigator.pushReplacementNamed(context, '/getstarted');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f4f4),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enlarged logo
            Image.asset(
              'assets/images/logo.png',
              height: 160, // increased size
            ),
            const SizedBox(height: 30),
            const Text(
              "SmartPay",
              style: TextStyle(
                fontSize: 40, // larger font size
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
