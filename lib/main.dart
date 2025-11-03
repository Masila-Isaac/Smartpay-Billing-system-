import 'package:flutter/material.dart';
import 'package:smartpay/screens/login.dart';
import 'package:smartpay/screens/signup.dart';
import 'package:smartpay/screens/dashboard.dart';
import 'package:smartpay/screens/viewreport.dart';

void main() {
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/dashboard',
      routes: {
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const Dashboard(),
        '/viewreport': (context) => const ViewReport(),
      },
    );
  }
}
