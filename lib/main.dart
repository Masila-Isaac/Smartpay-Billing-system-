import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/splashscreen.dart';
import 'screens/get_started_screen.dart';
import 'screens/login.dart';
import 'screens/signup.dart';
import 'screens/dashboard.dart';
import 'screens/viewreport.dart';
import 'screens/payment_options_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartPay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),

      // ALWAYS start from splash screen
      home: const SplashScreen(),

      // Routes
      routes: {
        '/getstarted': (context) => const GetStartedScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const Dashboard(),
        '/viewreport': (context) => const ViewReport(),
        '/paymentoptions': (context) => const PaymentOptionsScreen(),
      },
    );
  }
}
