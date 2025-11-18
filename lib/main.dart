import 'package:flutter/material.dart';
import 'package:smartpay/services/auth_service.dart';
import 'screens/splashscreen.dart';
import 'screens/get_started_screen.dart';
import 'screens/login.dart';
import 'screens/signup.dart';
import 'screens/dashboard.dart';
import 'screens/viewreport.dart';
import 'screens/payment_options_screen.dart';
import 'screens/water_usage_screen.dart';
import 'screens/water_reading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await AuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show splash screen while checking login status
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Image.asset(
              'assets/images/logo.png',
              height: 80,
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'SmartPay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      // Redirect to dashboard if already logged in, otherwise to splash screen
      home: _isLoggedIn ? const Dashboard() : const SplashScreen(),
      routes: {
        '/getstarted': (context) => const GetStartedScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const Dashboard(),
        '/viewreport': (context) => const ViewReport(),
        '/paymentoptions': (context) => const PaymentOptionsScreen(),
        '/waterusage': (context) => const WaterUsageScreen(),
        '/waterreading': (context) => const WaterReadingScreen(),
      },
    );
  }
}