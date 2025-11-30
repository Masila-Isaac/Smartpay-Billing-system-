import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Add error handling for Firebase initialization
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("🔥 Firebase initialization error: $e");
    // You might want to show an error screen or use fallback
  }

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          centerTitle: true,
        ),
      ),

      // Enhanced auto-login logic with better loading states
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show splash screen while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          // Handle errors in auth stream
          if (snapshot.hasError) {
            print("🔴 Auth stream error: ${snapshot.error}");
            return const GetStartedScreen(); // Fallback to login screen
          }

          // User is logged in - go to dashboard
          if (snapshot.hasData && snapshot.data != null) {
            final user = snapshot.data!;
            return Dashboard(
              userId: user.uid,
              userName: user.displayName ?? 'User',
              userEmail: user.email ?? '',
              meterNumber: '', // Fetch this from Firestore if available
            );
          }

          // User is not logged in - go to get started screen
          return const GetStartedScreen();
        },
      ),

      // Routes for navigation
      routes: {
        '/getstarted': (context) => const GetStartedScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => Dashboard(
              userId: '',
              userName: '',
              userEmail: '',
              meterNumber: '',
            ),
        '/viewreport': (context) => const ViewReport(meterNumber: ''),
        '/paymentoptions': (context) =>
            const PaymentOptionsScreen(meterNumber: ''),
      },

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.0)),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
