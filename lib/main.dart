import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:smartpay/screens/login.dart';
import 'package:smartpay/screens/signup.dart';
import 'package:smartpay/screens/dashboard.dart';
import 'package:smartpay/screens/viewreport.dart';
import 'package:smartpay/screens/splashscreen.dart';
import 'package:smartpay/screens/get_started_screen.dart';
import 'package:smartpay/screens/water_usage_screen.dart';
import 'package:smartpay/screens/payment_options_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      home: const SplashScreen(),
      routes: {
        '/getstarted': (context) => const GetStartedScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const Dashboard(),
        '/viewreport': (context) => const ViewReport(),
        '/paymentoptions': (context) => const PaymentOptionsScreen(),
        // Remove this line - WaterUsageScreen requires a parameter
        // '/waterusage': (context) => const WaterUsageScreen(),
      },
    );
  }
}
