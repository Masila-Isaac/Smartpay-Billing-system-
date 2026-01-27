// main.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart' show Provider, ChangeNotifierProvider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartpay/provider/county_theme_provider.dart'
    show CountyThemeProvider;
import 'package:smartpay/screens/county_selection.dart';
import 'package:smartpay/screens/dashboard.dart';
import 'package:smartpay/screens/login.dart';
import 'package:smartpay/screens/splashscreen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Get saved county or default to Nairobi
  final prefs = await SharedPreferences.getInstance();
  final savedCounty = prefs.getString('user_county') ?? '001';

  runApp(
    ChangeNotifierProvider(
      create: (context) => CountyThemeProvider(savedCounty),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<CountyThemeProvider>(context);

    return MaterialApp(
      title: 'SmartPay Kenya',
      theme: themeProvider.theme,
      debugShowCheckedModeBanner: false,
      home: const AuthChecker(),
      routes: {
        '/dashboard': (context) {
          // FIXED: Added null safety check
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args == null || args is! Map) {
            // Return to login if no arguments
            return const LoginScreen();
          }

          try {
            return Dashboard(
              userId: args['userId'] ?? '',
              meterNumber: args['meterNumber'] ?? '',
              userName: args['userName'] ?? '',
              userEmail: args['userEmail'] ?? '',
              countyCode: args['countyCode'] ?? '001',
            );
          } catch (e) {
            // Fallback if arguments are invalid
            return const LoginScreen();
          }
        },
        '/county-selection': (context) {
          // FIXED: Added null safety check
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args == null || args is! Map) {
            // Show error screen
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 20),
                    const Text(
                      'Invalid navigation',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text('Go to Login'),
                    ),
                  ],
                ),
              ),
            );
          }

          try {
            return CountySelectionScreen(
              userId: args['userId'] ?? '',
              meterNumber: args['meterNumber'] ?? '',
              userName: args['userName'] ?? '',
              userEmail: args['userEmail'] ?? '',
            );
          } catch (e) {
            return const LoginScreen();
          }
        },
        '/login': (context) => const LoginScreen(),
        '/splash': (context) => const SplashScreen(),
        '/auth-checker': (context) => const AuthChecker(),
      },
    );
  }
}

// AuthChecker widget implementation
class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData) {
          // User is logged in
          final user = snapshot.data!;
          return _buildUserProfileCheck(user);
        }

        // User is not logged in
        return const LoginScreen();
      },
    );
  }

  Widget _buildUserProfileCheck(User user) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (userSnap.hasError) {
          return _buildErrorScreen(userSnap.error.toString());
        }

        if (userSnap.hasData && userSnap.data!.exists) {
          final userData = userSnap.data!.data() as Map<String, dynamic>?;

          // FIXED: Added null check for userData
          if (userData == null) {
            return _buildErrorScreen('User data is null');
          }

          final county = userData['county'] as String?;
          final meterNumber = userData['meterNumber'] as String? ?? '';

          if (county == null || county.isEmpty) {
            // Redirect to county selection
            return CountySelectionScreen(
              userId: user.uid,
              meterNumber: meterNumber,
              userName:
                  userData['name'] as String? ?? user.displayName ?? 'User',
              userEmail: userData['email'] as String? ?? user.email ?? '',
            );
          } else {
            // Go to dashboard with county
            return Dashboard(
              userId: user.uid,
              meterNumber: meterNumber,
              userName:
                  userData['name'] as String? ?? user.displayName ?? 'User',
              userEmail: userData['email'] as String? ?? user.email ?? '',
              countyCode: county,
            );
          }
        }

        // User data doesn't exist in Firestore, create it and show splash
        _createUserProfile(user);
        return const SplashScreen();
      },
    );
  }

  Widget _buildErrorScreen(String error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/auth-checker'),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createUserProfile(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'county': null,
        'meterNumber': '',
        'isEmailVerified': user.emailVerified,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error creating user profile: $e');
    }
  }
}
