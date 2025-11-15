import 'package:flutter/material.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f4f4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // space between top and bottom
            children: [
              const SizedBox(), // top spacer

              // Centered logo and text
              Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 220, // much larger
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    "SmartPay",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40, // larger text
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Keep the flow going",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20, // slightly larger subtitle
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              // Bottom button
              Padding(
                padding: const EdgeInsets.only(bottom: 40.0), // add space from bottom edge
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                      shadowColor: Colors.black12,
                    ),
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Get started",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 18, // slightly larger button text
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: Colors.black87, size: 22),
                      ],
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
