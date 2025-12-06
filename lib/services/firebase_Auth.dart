import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with email and password
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = credential.user;

      if (user != null) {
        // Create initial account details
        await _firestore.collection("account_details").doc(user.uid).set({
          "uid": user.uid,
          "email": email,
          "created_at": FieldValue.serverTimestamp(),
          "updated_at": FieldValue.serverTimestamp(),
        });

        _showSnackBar(context, "Account created successfully", Colors.green);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred. Please try again.";

      switch (e.code) {
        case 'weak-password':
          message = "Password is too weak. Use at least 6 characters.";
          break;
        case 'email-already-in-use':
          message = "Email already in use. Try logging in instead.";
          break;
        case 'invalid-email':
          message = "Invalid email address.";
          break;
        case 'operation-not-allowed':
          message = "Email/password accounts are not enabled.";
          break;
      }

      _showSnackBar(context, message, Colors.red[400]!);
      return null;
    } catch (e) {
      _showSnackBar(context, "An unexpected error occurred", Colors.red[400]!);
      return null;
    }
  }

  // Login with email and password
  Future<User?> loginWithEmail({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login time
      await _updateLastLogin(credential.user!.uid);

      _showSnackBar(context, "Login successful", Colors.green);

      return credential.user;
    } on FirebaseAuthException catch (e) {
      String message = "Login failed. Please check your credentials.";

      switch (e.code) {
        case 'user-not-found':
          message = "No account found with this email.";
          break;
        case 'wrong-password':
          message = "Incorrect password. Please try again.";
          break;
        case 'invalid-email':
          message = "Invalid email address.";
          break;
        case 'user-disabled':
          message = "This account has been disabled.";
          break;
        case 'too-many-requests':
          message = "Too many attempts. Please try again later.";
          break;
      }

      _showSnackBar(context, message, Colors.red[400]!);
      return null;
    } catch (e) {
      _showSnackBar(context, "An unexpected error occurred", Colors.red[400]!);
      return null;
    }
  }

  // Update last login time
  Future<void> _updateLastLogin(String uid) async {
    try {
      await _firestore.collection("account_details").doc(uid).update({
        "last_login": FieldValue.serverTimestamp(),
        "updated_at": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error updating last login: $e");
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get current user email
  String? get currentUserEmail => _auth.currentUser?.email;

  // Password reset
  Future<void> resetPassword({
    required String email,
    required BuildContext context,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showSnackBar(context, "Password reset email sent", Colors.green);
    } on FirebaseAuthException catch (e) {
      String message = "Failed to send reset email.";

      switch (e.code) {
        case 'user-not-found':
          message = "No account found with this email.";
          break;
        case 'invalid-email':
          message = "Invalid email address.";
          break;
      }

      _showSnackBar(context, message, Colors.red[400]!);
    } catch (e) {
      _showSnackBar(context, "An unexpected error occurred", Colors.red[400]!);
    }
  }

  // Update user profile
  Future<void> updateProfile({
    required String displayName,
    String? photoURL,
    required BuildContext context,
  }) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      if (photoURL != null) {
        await _auth.currentUser?.updatePhotoURL(photoURL);
      }
      _showSnackBar(context, "Profile updated successfully", Colors.green);
    } catch (e) {
      _showSnackBar(context, "Failed to update profile", Colors.red[400]!);
    }
  }

  // Update email
  Future<void> updateEmail({
    required String newEmail,
    required BuildContext context,
  }) async {
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
      _showSnackBar(
          context, "Verification email sent to new address", Colors.green);
    } catch (e) {
      _showSnackBar(context, "Failed to update email", Colors.red[400]!);
    }
  }

  // Update password
  Future<void> updatePassword({
    required String newPassword,
    required BuildContext context,
  }) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      _showSnackBar(context, "Password updated successfully", Colors.green);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnackBar(context, "Please re-authenticate to update password",
            Colors.orange);
      } else {
        _showSnackBar(context, "Failed to update password", Colors.red[400]!);
      }
    } catch (e) {
      _showSnackBar(context, "An unexpected error occurred", Colors.red[400]!);
    }
  }

  // Delete account
  Future<void> deleteAccount({
    required BuildContext context,
  }) async {
    try {
      await _auth.currentUser?.delete();
      _showSnackBar(context, "Account deleted successfully", Colors.green);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnackBar(
            context, "Please re-authenticate to delete account", Colors.orange);
      } else {
        _showSnackBar(context, "Failed to delete account", Colors.red[400]!);
      }
    } catch (e) {
      _showSnackBar(context, "An unexpected error occurred", Colors.red[400]!);
    }
  }

  // Re-authenticate user
  Future<bool> reauthenticate({
    required String password,
    required BuildContext context,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      _showSnackBar(context, "Authentication failed", Colors.red[400]!);
      return false;
    }
  }

  // Helper method to show snackbar
  void _showSnackBar(
      BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
