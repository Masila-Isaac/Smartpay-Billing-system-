import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<User?> signInWithGoogle(BuildContext context) async {
    try {
      print('🔵 Starting Google Sign-In...');

      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

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
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');

      // Handle specific Firebase errors
      String errorMessage = 'Failed to sign in with Google';
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage =
              'An account already exists with the same email but different sign-in credentials.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid credential. Please try again.';
          break;
        case 'operation-not-allowed':
          errorMessage =
              'Google Sign-In is not enabled. Please contact support.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        default:
          errorMessage = 'Authentication failed: ${e.message}';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    } catch (e) {
      print('❌ Google Sign-In Error: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign in with Google: ${e.toString()}'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
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
        'currentRemainingBalance': 0.0,
        'currentWaterUsed': 0.0,
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

      // Create water usage document
      await _firestore.collection("waterUsage").doc(meterNumber).set({
        "meterNumber": meterNumber,
        "userId": user.uid,
        "accountNumber": accountNumber,
        "phone": user.phoneNumber ?? '',
        "currentReading": 0.0,
        "previousReading": 0.0,
        "unitsConsumed": 0.0,
        "remainingUnits": 0.0,
        "totalUnitsPurchased": 0.0,
        "lastReadingDate": FieldValue.serverTimestamp(),
        "timestamp": FieldValue.serverTimestamp(),
        "lastUpdated": FieldValue.serverTimestamp(),
        "status": "active",
      });

      print('✅ Water usage document created');

      // Create dashboard data
      await _firestore.collection("dashboard_data").doc(user.uid).set({
        "remainingBalance": 0.0,
        "waterUsed": 0.0,
        "totalPurchased": 0.0,
        "meterNumber": meterNumber,
        "lastUpdated": FieldValue.serverTimestamp(),
      });

      print('✅ Dashboard data document created');
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
