import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/deep/error_handler.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthProvider() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _fetchUserData(user.uid);
      } else {
        _userData = null;
      }
      notifyListeners();
    });
  }

  Future<void> _fetchUserData(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (userSnapshot.exists) {
        _userData = userSnapshot.data() as Map<String, dynamic>;
      }
    } catch (e) {
      _error = ErrorHandler.getFirebaseFirestoreError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<User?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      return credential.user;
    } on FirebaseAuthException catch (e) {
      _error = ErrorHandler.getFirebaseAuthError(e.code);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Create user with Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        ...userData,
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return credential.user;
    } on FirebaseAuthException catch (e) {
      _error = ErrorHandler.getFirebaseAuthError(e.code);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _auth.signOut();
      _user = null;
      _userData = null;
    } catch (e) {
      _error = 'Failed to logout';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      _error = ErrorHandler.getFirebaseAuthError(e.code);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_user != null) {
        await _firestore.collection('users').doc(_user!.uid).update({
          ...updates,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Refresh user data
        await _fetchUserData(_user!.uid);
      }
    } catch (e) {
      _error = 'Failed to update profile';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
