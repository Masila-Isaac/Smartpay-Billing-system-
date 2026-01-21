import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:smartpay/core/validators/form_validators.dart';
import 'package:smartpay/deep/error_handler.dart';
import 'package:smartpay/deep/load_overlay.dart';
import 'package:smartpay/screens/dashboard.dart';
import 'package:smartpay/screens/signup.dart';
import 'package:smartpay/services/firebase_Auth.dart';
import 'package:smartpay/services/google_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool obscurePassword = true;
  bool isLoading = false;
  bool isNavigatingToSignUp = false;
  bool isResettingPassword = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

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
      if (mounted) {
        _showSnackBar(
          ErrorHandler.getFirebaseAuthError(e.toString()),
          Colors.red[400]!,
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => isLoading = true);

    try {
      final user = await GoogleAuthService.signInWithGoogle(context);

      if (user != null && mounted) {
        // Navigate to dashboard
        await _navigateToDashboard(user.uid);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Google Sign-In failed: ${e.toString()}',
          Colors.red[400]!,
        );
      }
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
          countyCode: '',
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

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(
      text: this.emailController.text,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LoadingOverlay(
        isLoading: isResettingPassword,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: Colors.blue),
              SizedBox(width: 8),
              Text('Reset Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your email to receive a reset link:'),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: FormValidators.validateEmail,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isResettingPassword ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isResettingPassword
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      final error = FormValidators.validateEmail(email);

                      if (error != null) {
                        _showSnackBar(error, Colors.red[400]!);
                        return;
                      }

                      setState(() => isResettingPassword = true);

                      try {
                        await FirebaseAuth.instance.sendPasswordResetEmail(
                          email: email,
                        );

                        if (mounted) {
                          Navigator.pop(context);
                          _showSnackBar(
                            'Password reset link sent to $email',
                            Colors.green,
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          _showSnackBar(
                            ErrorHandler.getFirebaseAuthError(e.toString()),
                            Colors.red[400]!,
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => isResettingPassword = false);
                        }
                      }
                    },
              child: const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: isNavigatingToSignUp,
      loadingText: 'Loading...',
      child: Scaffold(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Form(
                  key: _formKey,
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
                        validator: FormValidators.validateEmail,
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(),

                      // Forgot Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isLoading ? null : _forgotPassword,
                          child: Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
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
                            onTap:
                                isNavigatingToSignUp ? null : _navigateToSignUp,
                            child: isNavigatingToSignUp
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
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

                      // Google Sign In - NOW ENABLED
                      _buildGoogleButton(),
                    ],
                  ),
                ),
              ),
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
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
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
      child: TextFormField(
        controller: controller,
        enabled: !isLoading,
        keyboardType: keyboardType ?? TextInputType.emailAddress,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontSize: 16),
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red[400]!, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red[400]!, width: 2),
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
      child: TextFormField(
        controller: passwordController,
        obscureText: obscurePassword,
        enabled: !isLoading,
        style: const TextStyle(fontSize: 16),
        validator: FormValidators.validatePasswordSimple,
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red[400]!, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red[400]!, width: 2),
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
        onPressed: isLoading ? null : _signInWithGoogle,
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
