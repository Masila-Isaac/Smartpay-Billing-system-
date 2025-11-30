import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/screens/login.dart';
import 'package:smartpay/services/firebase_Auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool obscurePassword = true;
  bool _isLoading = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuthService authService = FirebaseAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    if (passwordController.text.length < 6) {
      _showErrorDialog('Password must be at least 6 characters long');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await authService.signUpWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        context: context,
      );

      if (user != null) {
        // Generate meter number
        String meterNumber = "MTR${DateTime.now().millisecondsSinceEpoch}";

        // Create user document in Firestore
        await _firestore.collection("users").doc(user.uid).set({
          "email": emailController.text.trim(),
          "name": nameController.text.trim(),
          "meterNumber": meterNumber,
          "phone": "", // Initialize empty phone
          "address": "", // Initialize empty address
          "location": "", // Initialize empty location
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });

        // Create clients collection document (this is what payments update)
        await _firestore.collection("clients").doc(meterNumber).set({
          "meterNumber": meterNumber,
          "userId": user.uid,
          "phone": "",
          "waterUsed": 0.0,
          "remainingLitres": 0.0,
          "totalLitresPurchased": 0.0,
          "lastTopUp": FieldValue.serverTimestamp(),
          "lastUpdated": FieldValue.serverTimestamp(),
          "status": "active",
          "createdAt": FieldValue.serverTimestamp(),
        });

        // Create waterUsage collection document
        await _firestore.collection("waterUsage").doc(meterNumber).set({
          "meterNumber": meterNumber,
          "userId": user.uid,
          "phone": "",
          "waterUsed": 0.0,
          "remainingUnits": 0.0,
          "totalUnitsPurchased": 0.0,
          "timestamp": FieldValue.serverTimestamp(),
          "lastUpdated": FieldValue.serverTimestamp(),
          "status": "active",
        });

        // Create account_details collection document
        await _firestore.collection("account_details").doc(user.uid).set({
          "userId": user.uid,
          "meterNumber": meterNumber,
          "name": nameController.text.trim(),
          "email": emailController.text.trim(),
          "phone": "",
          "address": "",
          "location": "",
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });

        print('✅ User created successfully across all collections');
        print('📊 User ID: ${user.uid}');
        print('📊 Meter Number: $meterNumber');

        // Show success message
        _showSuccessDialog(meterNumber);
      }
    } catch (e) {
      print('❌ Sign up error: $e');
      _showErrorDialog('Sign up failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String meterNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Success'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Account created successfully!'),
              const SizedBox(height: 8),
              Text(
                'Your Meter Number:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  meterNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please save this meter number for future reference.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Continue to Login'),
            ),
          ],
        );
      },
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
            // ... (keep all your existing UI code exactly the same)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 40,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  "SmartPay",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const Text(
              "Create an Account",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Sign up to continue with your journey",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 40),
            _buildTextField(
              controller: nameController,
              hint: "Full Name",
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: emailController,
              hint: "Email Address",
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 20),
            _buildPasswordField(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text(
                        "Sign Up",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            _buildDividerWithOr(),
            const SizedBox(height: 32),
            _buildSocialIcons(),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Already have an account? ",
                  style: TextStyle(color: Colors.black54, fontSize: 15),
                ),
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          );
                        },
                  child: Text(
                    "Sign In",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _isLoading ? Colors.grey : Colors.blueAccent,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isLoading,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.black54),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: passwordController,
      obscureText: obscurePassword,
      enabled: !_isLoading,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
        hintText: "Password",
        filled: true,
        fillColor: Colors.grey[50],
        suffixIcon: IconButton(
          icon: Icon(
            obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: () {
            setState(() => obscurePassword = !obscurePassword);
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDividerWithOr() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text("or", style: TextStyle(color: Colors.grey[500])),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }

  Widget _buildSocialIcons() {
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
        color: Colors.grey[50],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: FaIcon(icon, size: 22, color: Colors.black87),
    );
  }
}
