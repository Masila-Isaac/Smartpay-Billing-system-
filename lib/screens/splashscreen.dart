import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:smartpay/services/auth_service.dart';
import '../firebase_options.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  bool _firebaseInitialized = false;
  bool _navigationCompleted = false;
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Start animation
    _controller.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Start Firebase initialization but don't wait for it
    final firebaseFuture = Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then((_) {
      if (mounted) {
        setState(() {
          _firebaseInitialized = true;
        });
      }
      print("Firebase initialized successfully");
    }).catchError((error) {
      print("Firebase initialization error: $error");
      // Continue even if Firebase fails
      if (mounted) {
        setState(() {
          _firebaseInitialized = true;
        });
      }
    });

    // Check if user is already logged in
    final isLoggedIn = await AuthService.isLoggedIn();

    // Wait for exactly 3 seconds total splash time
    await Future.delayed(const Duration(seconds: 3));

    // Navigate to appropriate screen
    if (mounted && !_navigationCompleted) {
      _navigationCompleted = true;

      if (isLoggedIn) {
        // User is logged in, go to dashboard
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        // User is not logged in, go to get started
        Navigator.pushReplacementNamed(context, '/getstarted');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f4f4),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 160,
                filterQuality: FilterQuality.low,
              ),
              const SizedBox(height: 30),
              const Text(
                "SmartPay",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _firebaseInitialized ? Colors.green : Colors.blueAccent,
                  ),
                ),
              ),
              if (!_firebaseInitialized) ...[
                const SizedBox(height: 10),
                const Text(
                  "Initializing...",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}