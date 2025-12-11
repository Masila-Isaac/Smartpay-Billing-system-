import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:smartpay/core/validators/form_validators.dart';
import 'package:smartpay/deep/error_handler.dart';
import 'package:smartpay/deep/load_overlay.dart' show LoadingOverlay;
import 'package:smartpay/deep/password_strength.dart';
import 'package:smartpay/screens/dashboard.dart';
import 'package:smartpay/services/firebase_Auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool obscurePassword = true;
  bool isLoading = false;
  bool _showPasswordTips = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuthService authService = FirebaseAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    passwordController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    idNumberController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String _generateMeterNumber() {
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String random = (DateTime.now().microsecondsSinceEpoch % 10000)
        .toString()
        .padLeft(4, '0');
    return "MTR${timestamp.substring(timestamp.length - 6)}$random";
  }

  String _generateAccountNumber() {
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String random = (DateTime.now().microsecondsSinceEpoch % 10000)
        .toString()
        .padLeft(4, '0');
    return "ACC${timestamp.substring(timestamp.length - 6)}$random";
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix the errors in the form', Colors.red[400]!);
      return;
    }

    // Check password strength
    final passwordStrength = FormValidators.checkPasswordStrength(
      passwordController.text,
    );
    if (passwordStrength == PasswordStrength.weak) {
      final shouldContinue = await _showWeakPasswordDialog();
      if (!shouldContinue) {
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      final String meterNumber = _generateMeterNumber();
      final String accountNumber = _generateAccountNumber();
      final String phone = phoneController.text.trim();
      final String idNumber = idNumberController.text.trim();
      final String name = nameController.text.trim();
      final String email = emailController.text.trim();

      // Check for existing email
      final emailSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailSnapshot.docs.isNotEmpty) {
        _showSnackBar('Email already exists. Please use a different email.',
            Colors.red[400]!);
        setState(() => isLoading = false);
        return;
      }

      // Create user with Firebase Authentication
      final user = await authService.signUpWithEmail(
        email: email,
        password: passwordController.text.trim(),
        context: context,
      );

      if (user != null) {
        // Create user document in Firestore
        await _firestore.collection("users").doc(user.uid).set({
          "email": email,
          "name": name,
          "phone": phone,
          "idNumber": idNumber,
          "meterNumber": meterNumber,
          "accountNumber": accountNumber,
          "address": "",
          "location": "",
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
          "userType": "customer",
          "status": "active",
          "currentRemainingBalance": 0.0,
          "currentWaterUsed": 0.0,
          "lastWaterUpdate": FieldValue.serverTimestamp(),
        });

        // Create clients collection document
        await _firestore.collection("clients").doc(meterNumber).set({
          "meterNumber": meterNumber,
          "userId": user.uid,
          "accountNumber": accountNumber,
          "name": name,
          "phone": phone,
          "idNumber": idNumber,
          "email": email,
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
          "accountNumber": accountNumber,
          "phone": phone,
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

        // Create account_details collection document
        await _firestore.collection("account_details").doc(user.uid).set({
          "userId": user.uid,
          "meterNumber": meterNumber,
          "accountNumber": accountNumber,
          "name": name,
          "email": email,
          "phone": phone,
          "idNumber": idNumber,
          "address": "",
          "location": "",
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });

        // Create dashboard_data document
        await _firestore.collection("dashboard_data").doc(user.uid).set({
          "remainingBalance": 0.0,
          "waterUsed": 0.0,
          "totalPurchased": 0.0,
          "meterNumber": meterNumber,
          "lastUpdated": FieldValue.serverTimestamp(),
        });

        print('✅ User created successfully across all collections');

        // Navigate directly to Dashboard
        _navigateToDashboard(
          userId: user.uid,
          meterNumber: meterNumber,
          userName: name,
          userEmail: email,
        );
      }
    } catch (e) {
      print('❌ Sign up error: $e');
      _showSnackBar(
        ErrorHandler.getFirebaseAuthError(e.toString()),
        Colors.red[400]!,
      );
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<bool> _showWeakPasswordDialog() async {
    return await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Weak Password'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your password is weak. For better security, we recommend:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 12),
                _PasswordTipItem(text: 'At least 8 characters'),
                _PasswordTipItem(text: 'One uppercase letter'),
                _PasswordTipItem(text: 'One lowercase letter'),
                _PasswordTipItem(text: 'One number'),
                _PasswordTipItem(text: 'One special character'),
                SizedBox(height: 12),
                Text(
                  'You can continue with your current password, but it may be less secure.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Improve Password'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue Anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _navigateToDashboard({
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
      isLoading: isLoading,
      loadingText: 'Creating account...',
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Gradient background decoration
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
                      // Back Button and Logo
                      Row(
                        children: [
                          IconButton(
                            onPressed:
                                isLoading ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            color: Colors.black87,
                          ),
                          const Spacer(),
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
                      const SizedBox(height: 40),

                      // Title
                      const Text(
                        "Create Account",
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
                        "Fill in your details to get started",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Full Name Field
                      _buildTextField(
                        controller: nameController,
                        hint: "Full Name",
                        icon: Icons.person_outline,
                        validator: FormValidators.validateName,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s]'))
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Phone Number Field
                      _buildTextField(
                        controller: phoneController,
                        hint: "Phone Number",
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: FormValidators.validatePhone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ID Number Field
                      _buildTextField(
                        controller: idNumberController,
                        hint: "Identification Number",
                        icon: Icons.badge_outlined,
                        keyboardType: TextInputType.number,
                        validator: FormValidators.validateIdNumber,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      _buildTextField(
                        controller: emailController,
                        hint: "Email Address",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: FormValidators.validateEmail,
                      ),
                      const SizedBox(height: 16),

                      // Password Field with Strength Indicator
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPasswordField(
                            controller: passwordController,
                            hint: "Password",
                            obscureText: obscurePassword,
                            onToggleVisibility: () => setState(
                                () => obscurePassword = !obscurePassword),
                          ),
                          const SizedBox(height: 8),
                          PasswordStrengthIndicator(
                            password: passwordController.text,
                            showText: true,
                          ),
                          if (_showPasswordTips) _buildPasswordTips(),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Auto-generated Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.blue[700], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Auto-generated Information",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[800],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "• Meter number will be auto-generated\n"
                              "• Account number will be auto-generated\n"
                              "• You can view these in your profile",
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Terms and Conditions Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: true,
                            onChanged: null,
                            activeColor: Colors.blue[600],
                          ),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'I agree to the ',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' and ',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _signUp,
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
                                  "Sign Up",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 15,
                            ),
                          ),
                          GestureDetector(
                            onTap:
                                isLoading ? null : () => Navigator.pop(context),
                            child: Text(
                              "Log In",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.blue[700],
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
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
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
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
        keyboardType: keyboardType,
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
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
        obscureText: obscureText,
        enabled: !isLoading,
        style: const TextStyle(fontSize: 16),
        validator: FormValidators.validatePassword,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onTap: () {
          setState(() => _showPasswordTips = true);
        },
        decoration: InputDecoration(
          prefixIcon:
              Icon(Icons.lock_outline, color: Colors.grey[600], size: 22),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.grey[600],
              size: 22,
            ),
            onPressed: isLoading ? null : onToggleVisibility,
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

  Widget _buildPasswordTips() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password must contain:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blue[800],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          _buildPasswordTip('At least 8 characters'),
          _buildPasswordTip('One uppercase letter (A-Z)'),
          _buildPasswordTip('One lowercase letter (a-z)'),
          _buildPasswordTip('One number (0-9)'),
          _buildPasswordTip('One special character (!@#\$%^&*)'),
        ],
      ),
    );
  }

  Widget _buildPasswordTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: Colors.blue[400],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordTipItem extends StatelessWidget {
  final String text;

  const _PasswordTipItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
