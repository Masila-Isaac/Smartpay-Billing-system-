import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/screens/dashboard.dart';
import 'package:smartpay/screens/login.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 🔥 If user already logged in → fetch user data and go to Dashboard
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (userSnapshot.hasError) {
                // If there's an error fetching user data, log out and show login
                FirebaseAuth.instance.signOut();
                return const LoginScreen();
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;

                return Dashboard(
                  userId: snapshot.data!.uid,
                  meterNumber: userData['meterNumber'] ?? '',
                  userName: userData['name'] ?? 'User',
                  userEmail: userData['email'] ?? '',
                );
              } else {
                // If user document doesn't exist, log out and show login
                FirebaseAuth.instance.signOut();
                return const LoginScreen();
              }
            },
          );
        }

        // If NOT logged in → show login screen
        return const LoginScreen();
      },
    );
  }
}
