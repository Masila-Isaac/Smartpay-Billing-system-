import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/screens/login.dart';

class GoogleAuthService {
  // Initialize Google Sign-In
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<User?> signInWithGoogle(BuildContext context) async {
    try {
      print('🔵 Starting Google Sign-In...');

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (googleUser == null) {
        print('🟡 User cancelled Google Sign-In');
        return null;
      }

      print('🟢 Google user obtained: ${googleUser.email}');

      // Obtain auth details from request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🟢 Signing in to Firebase with Google credential...');

      // Sign in to Firebase with Google credential
      final UserCredential authResult =
          await _auth.signInWithCredential(credential);
      final User? user = authResult.user;

      if (user != null) {
        print('✅ Firebase user created: ${user.uid}, ${user.email}');

        // Check if user already exists in Firestore
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          print('🟡 Creating new user document in Firestore...');
          await _createUserDocument(user);
        } else {
          print('✅ User already exists in Firestore');
        }

        return user;
      }

      print('🔴 No user returned from Firebase');
      return null;
    } catch (e) {
      print('❌ Google Sign-In Error: $e');

      // Show error to user
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign-In Error'),
            content: Text('Failed to sign in with Google: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      rethrow;
    }
  }

  static Future<void> _createUserDocument(User user) async {
    try {
      // Create meter and account numbers
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final meterNumber = "MTR${timestamp.substring(timestamp.length - 8)}";
      final accountNumber = "ACC${timestamp.substring(timestamp.length - 8)}";

      // Create user document in 'users' collection
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'name': user.displayName ?? 'User',
        'phone': user.phoneNumber ?? '',
        'photoUrl': user.photoURL ?? '',
        'meterNumber': meterNumber,
        'accountNumber': accountNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userType': 'customer',
        'status': 'active',
      });

      print('✅ User document created in Firestore');

      // Create in clients collection
      await _firestore.collection("clients").doc(meterNumber).set({
        "meterNumber": meterNumber,
        "userId": user.uid,
        "accountNumber": accountNumber,
        "name": user.displayName ?? '',
        "phone": user.phoneNumber ?? '',
        "idNumber": "",
        "email": user.email ?? '',
        "waterUsed": 0.0,
        "remainingLitres": 0.0,
        "totalLitresPurchased": 0.0,
        "lastTopUp": FieldValue.serverTimestamp(),
        "lastUpdated": FieldValue.serverTimestamp(),
        "status": "active",
        "createdAt": FieldValue.serverTimestamp(),
      });

      print('✅ Client document created');

      // Create in account_details
      await _firestore.collection("account_details").doc(user.uid).set({
        "userId": user.uid,
        "meterNumber": meterNumber,
        "accountNumber": accountNumber,
        "name": user.displayName ?? '',
        "email": user.email ?? '',
        "phone": user.phoneNumber ?? '',
        "idNumber": "",
        "address": "",
        "location": "",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      print('✅ Account details document created');
    } catch (e) {
      print('❌ Error creating user documents: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      print('✅ Signed out from Google and Firebase');
    } catch (e) {
      print('❌ Error signing out: $e');
    }
  }
}
