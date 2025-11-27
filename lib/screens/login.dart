import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/screens/signup.dart';
import 'package:smartpay/screens/dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool obscurePassword = true;
  bool _isLoading = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Get user data from Firestore
      DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userData.exists) {
        String meterNumber = userData['meterNumber'];
        String userName = userData['name'];
        String userEmail = userData['email'];

        // Update account_details collection with user information
        await _updateAccountDetails(
          userId: userCredential.user!.uid,
          meterNumber: meterNumber,
          userName: userName,
          userEmail: userEmail,
        );

        // Navigate to Dashboard with user data
        _navigateWithSlideTransition(
          context,
          Dashboard(
            userId: userCredential.user!.uid,
            meterNumber: meterNumber,
            userName: userName,
            userEmail: userEmail,
          ),
        );
      } else {
        _showErrorDialog('User data not found. Please sign up again.');
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog('Login failed. Please try again.');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateAccountDetails({
    required String userId,
    required String meterNumber,
    required String userName,
    required String userEmail,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('account_details')
          .doc(userId)
          .set({
        'userId': userId,
        'meterNumber': meterNumber,
        'name': userName,
        'email': userEmail,
        'lastLogin': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Account details updated for user: $userId');
    } catch (e) {
      print('Error updating account details: $e');
    }
  }

  void _navigateWithSlideTransition(BuildContext context, Widget page) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end);
          final offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        pageBuilder: (context, animation, secondaryAnimation) => page,
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error')
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset('assets/images/logo.png', height: 40),
                ),
                const SizedBox(width: 12),
                const Text(
                  "SmartPay",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text(
              "Welcome Back",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              "Sign in to continue your journey",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),
            _buildTextField(
                emailController, "Email Address", Icons.email_outlined),
            const SizedBox(height: 20),
            _buildPasswordField(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Log In",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 32),
            _buildDivider(),
            const SizedBox(height: 32),
            _buildSocialRow(),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?",
                    style: TextStyle(color: Colors.black54)),
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SignUpScreen())),
                  child: Text(
                    " Sign Up",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isLoading ? Colors.grey : Colors.blueAccent),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      enabled: !_isLoading,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 22, color: Colors.black54),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: passwordController,
      obscureText: obscurePassword,
      enabled: !_isLoading,
      decoration: InputDecoration(
        prefixIcon:
            const Icon(Icons.lock_outline, size: 22, color: Colors.black54),
        hintText: "Password",
        filled: true,
        fillColor: Colors.grey[50],
        suffixIcon: IconButton(
          icon: Icon(
            obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.black54,
          ),
          onPressed: _isLoading
              ? null
              : () => setState(() => obscurePassword = !obscurePassword),
        ),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text("or", style: TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }

  Widget _buildSocialRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialIcon(FontAwesomeIcons.apple),
        const SizedBox(width: 20),
        _socialIcon(FontAwesomeIcons.google),
        const SizedBox(width: 20),
        _socialIcon(FontAwesomeIcons.facebook),
      ],
    );
  }

  Widget _socialIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[50],
          border: Border.all(color: Colors.grey[200]!)),
      child: FaIcon(icon, size: 22, color: Colors.black87),
    );
  }
}
