import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/screens/dashboard.dart';
import 'package:smartpay/screens/signup.dart';
import 'package:smartpay/services/firebase_Auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool obscurePassword = true;
  bool isLoading = false;
  bool isNavigatingToSignUp = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter both email and password', Colors.red[400]!);
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await _authService.loginWithEmail(
        email: email,
        password: password,
        context: context,
      );

      if (user != null && mounted) {
        // Get user data from Firestore before navigating
        await _navigateToDashboard(user.uid);
      }
    } catch (e) {
      // Error handling is done in the service
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _navigateToDashboard(String userId) async {
    try {
      print('🔍 Fetching user data for userId: $userId');

      // Try to get user data from Firestore
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (userSnapshot.exists) {
        final userData = userSnapshot.data() as Map<String, dynamic>;

        String meterNumber = userData['meterNumber'] ?? '';
        String userName = userData['name'] ?? 'User';
        String userEmail = userData['email'] ?? emailController.text.trim();

        print('✅ User data fetched:');
        print('   - Name: $userName');
        print('   - Email: $userEmail');
        print('   - Meter: $meterNumber');

        // Navigate to Dashboard with user data
        _navigateToDashboardScreen(
          userId: userId,
          meterNumber: meterNumber,
          userName: userName,
          userEmail: userEmail,
        );
      } else {
        // If not in users collection, try account_details
        DocumentSnapshot accountSnapshot =
            await _firestore.collection('account_details').doc(userId).get();

        if (accountSnapshot.exists) {
          final accountData = accountSnapshot.data() as Map<String, dynamic>;

          String meterNumber = accountData['meterNumber'] ?? '';
          String userName = accountData['name'] ?? 'User';
          String userEmail =
              accountData['email'] ?? emailController.text.trim();

          _navigateToDashboardScreen(
            userId: userId,
            meterNumber: meterNumber,
            userName: userName,
            userEmail: userEmail,
          );
        } else {
          // Fallback - navigate with minimal data
          _showSnackBar('User profile incomplete', Colors.orange);
          _navigateToDashboardScreen(
            userId: userId,
            meterNumber: '',
            userName: 'User',
            userEmail: emailController.text.trim(),
          );
        }
      }
    } catch (e) {
      print('❌ Error fetching user data: $e');
      _showSnackBar('Error loading user data', Colors.red[400]!);
      // Fallback navigation
      _navigateToDashboardScreen(
        userId: userId,
        meterNumber: '',
        userName: 'User',
        userEmail: emailController.text.trim(),
      );
    }
  }

  void _navigateToDashboardScreen({
    required String userId,
    required String meterNumber,
    required String userName,
    required String userEmail,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => Dashboard(
          userId: userId,
          meterNumber: meterNumber,
          userName: userName,
          userEmail: userEmail,
        ),
      ),
    );
  }

  void _navigateToSignUp() async {
    setState(() => isNavigatingToSignUp = true);

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignUpScreen()),
      );
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
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

  void _forgotPassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your email to receive a reset link:'),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(),
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement password reset
              _showSnackBar('Reset link sent to your email', Colors.green);
              Navigator.pop(context);
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[50]!,
                  Colors.white,
                  Colors.purple[50]!,
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo Section
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/waterdroplet.jpg',
                          height: 40,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.water_drop,
                                  size: 40, color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "SmartPay",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: -0.5,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),

                  // Welcome Text
                  const Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.5,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Sign in to continue your journey",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Input Fields
                  _buildTextField(
                    controller: emailController,
                    hint: "Email Address",
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        disabledBackgroundColor: Colors.blue[300],
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              "Log In",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Sign Up Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: isNavigatingToSignUp ? null : _navigateToSignUp,
                        child: isNavigatingToSignUp
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                "Sign Up",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue[700],
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Divider
                  _buildDivider(),

                  const SizedBox(height: 32),

                  // Google Sign In (Placeholder)
                  _buildGoogleButton(),
                ],
              ),
            ),
          ),

          if (isNavigatingToSignUp)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: !isLoading,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 22),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: passwordController,
        obscureText: obscurePassword,
        enabled: !isLoading,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          prefixIcon:
              Icon(Icons.lock_outline, color: Colors.grey[600], size: 22),
          hintText: "Password",
          hintStyle: TextStyle(color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          suffixIcon: IconButton(
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey[600],
              size: 22,
            ),
            onPressed: isLoading
                ? null
                : () {
                    setState(() => obscurePassword = !obscurePassword);
                  },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(thickness: 1, color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "or",
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(child: Divider(thickness: 1, color: Colors.grey[300])),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading
            ? null
            : () {
                _showSnackBar(
                    'Google Sign-In coming soon!', Colors.orange[400]!);
              },
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey[800],
          side: BorderSide(color: Colors.grey[300]!, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google.png',
              height: 24,
              width: 24,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.g_mobiledata,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
