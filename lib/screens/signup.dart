import 'package:flutter/material.dart';
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
  bool isLoading = false;
  bool isNavigatingToLogin = false;
  bool _isAccountNumberAuto = true;
  bool _isMeterNumberAuto = true;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController meterNumberController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuthService authService = FirebaseAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _generateMeterNumber();
    _generateAccountNumber();
  }

  void _generateAccountNumber() {
    if (_isAccountNumberAuto) {
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String accountNumber = "ACC${timestamp.substring(timestamp.length - 8)}";
      accountNumberController.text = accountNumber;
    }
  }

  void _generateMeterNumber() {
    if (_isMeterNumberAuto) {
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String meterNumber = "MTR${timestamp.substring(timestamp.length - 8)}";
      meterNumberController.text = meterNumber;
    }
  }

  void _toggleAccountNumberAuto(bool? value) {
    if (value != null) {
      setState(() {
        _isAccountNumberAuto = value;
        if (value) {
          _generateAccountNumber();
        } else {
          accountNumberController.clear();
        }
      });
    }
  }

  void _toggleMeterNumberAuto(bool? value) {
    if (value != null) {
      setState(() {
        _isMeterNumberAuto = value;
        if (value) {
          _generateMeterNumber();
        } else {
          meterNumberController.clear();
        }
      });
    }
  }

  void _refreshMeterNumber() {
    if (_isMeterNumberAuto) {
      _generateMeterNumber();
    }
  }

  void _refreshAccountNumber() {
    if (_isAccountNumberAuto) {
      _generateAccountNumber();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    idNumberController.dispose();
    meterNumberController.dispose();
    accountNumberController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (passwordController.text.length < 6) {
      _showSnackBar(
          'Password must be at least 6 characters long', Colors.red[400]!);
      return;
    }

    if (!_isMeterNumberAuto && meterNumberController.text.isEmpty) {
      _showSnackBar(
          'Please enter or generate a meter number', Colors.red[400]!);
      return;
    }

    if (!_isAccountNumberAuto && accountNumberController.text.isEmpty) {
      _showSnackBar(
          'Please enter or generate an account number', Colors.red[400]!);
      return;
    }

    setState(() => isLoading = true);

    try {
      // Check for existing meter number
      final meterSnapshot = await _firestore
          .collection('clients')
          .where('meterNumber', isEqualTo: meterNumberController.text.trim())
          .limit(1)
          .get();

      if (meterSnapshot.docs.isNotEmpty) {
        _showSnackBar('Meter number already exists. Please generate a new one.',
            Colors.red[400]!);
        if (_isMeterNumberAuto) {
          _generateMeterNumber();
        }
        setState(() => isLoading = false);
        return;
      }

      // Check for existing account number
      final accountSnapshot = await _firestore
          .collection('account_details')
          .where('accountNumber',
              isEqualTo: accountNumberController.text.trim())
          .limit(1)
          .get();

      if (accountSnapshot.docs.isNotEmpty) {
        _showSnackBar(
            'Account number already exists. Please generate a new one.',
            Colors.red[400]!);
        if (_isAccountNumberAuto) {
          _generateAccountNumber();
        }
        setState(() => isLoading = false);
        return;
      }

      // Check for existing email
      final emailSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: emailController.text.trim())
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
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        context: context,
      );

      if (user != null) {
        final String meterNumber = meterNumberController.text.trim();
        final String accountNumber = accountNumberController.text.trim();
        final String phone = phoneController.text.trim();
        final String idNumber = idNumberController.text.trim();
        final String name = nameController.text.trim();
        final String email = emailController.text.trim();

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
        _showSuccessDialog(meterNumber, accountNumber);
      }
    } catch (e) {
      print('❌ Sign up error: $e');
      _showSnackBar('Sign up failed: ${e.toString()}', Colors.red[400]!);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSuccessDialog(String meterNumber, String accountNumber) {
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
              const Text(
                'Account created successfully!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _buildInfoItem('Meter Number:', meterNumber),
              const SizedBox(height: 8),
              _buildInfoItem('Account Number:', accountNumber),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  'Please save these numbers for future reference.',
                  style: TextStyle(
                    color: Colors.amber[800],
                    fontSize: 12,
                  ),
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

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
            fontSize: 14,
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
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navigateToLogin() async {
    setState(() => isNavigatingToLogin = true);

    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back Button and Logo
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Number Field
                    _buildTextField(
                      controller: phoneController,
                      hint: "Phone Number",
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (!RegExp(r'^[0-9]{10,15}$').hasMatch(value.trim())) {
                          return 'Please enter a valid phone number (10-15 digits)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ID Number Field
                    _buildTextField(
                      controller: idNumberController,
                      hint: "Identification Number",
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your ID number';
                        }
                        if (!RegExp(r'^[0-9]{6,12}$').hasMatch(value.trim())) {
                          return 'Please enter a valid ID number (6-12 digits)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Meter Number Field with Toggle
                    _buildTextFieldWithToggle(
                      controller: meterNumberController,
                      hint: "Meter Number",
                      icon: Icons.speed_outlined,
                      isAuto: _isMeterNumberAuto,
                      onToggle: _toggleMeterNumberAuto,
                      onGenerate: _refreshMeterNumber,
                      prefix: "MTR",
                    ),
                    const SizedBox(height: 16),

                    // Account Number Field with Toggle
                    _buildTextFieldWithToggle(
                      controller: accountNumberController,
                      hint: "Account Number",
                      icon: Icons.account_balance_outlined,
                      isAuto: _isAccountNumberAuto,
                      onToggle: _toggleAccountNumberAuto,
                      onGenerate: _refreshAccountNumber,
                      prefix: "ACC",
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    _buildTextField(
                      controller: emailController,
                      hint: "Email Address",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    _buildPasswordField(
                      controller: passwordController,
                      hint: "Password",
                      obscureText: obscurePassword,
                      onToggleVisibility: () =>
                          setState(() => obscurePassword = !obscurePassword),
                    ),
                    const SizedBox(height: 32),

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

                    // Divider
                    Row(
                      children: [
                        Expanded(
                            child:
                                Divider(thickness: 1, color: Colors.grey[300])),
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
                        Expanded(
                            child:
                                Divider(thickness: 1, color: Colors.grey[300])),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Google Sign In Button (Placeholder)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                _showSnackBar('Google Sign-Up coming soon!',
                                    Colors.orange[400]!);
                              },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.grey[800],
                          side:
                              BorderSide(color: Colors.grey[300]!, width: 1.5),
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
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.g_mobiledata,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign up with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

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
                          onTap: isNavigatingToLogin ? null : _navigateToLogin,
                          child: isNavigatingToLogin
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
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

          if (isNavigatingToLogin)
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
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
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
        style: const TextStyle(fontSize: 16),
        validator: validator,
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

  Widget _buildTextFieldWithToggle({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isAuto,
    required Function(bool?) onToggle,
    required VoidCallback onGenerate,
    required String prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  enabled: !isLoading && !isAuto,
                  style: TextStyle(
                    fontSize: 16,
                    color: isAuto ? Colors.grey[600] : Colors.black87,
                    fontWeight: isAuto ? FontWeight.w500 : FontWeight.normal,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(icon, color: Colors.grey[600], size: 22),
                    hintText: isAuto ? 'Auto-generated' : 'Enter $hint',
                    hintStyle: TextStyle(
                      color: isAuto ? Colors.grey[500] : Colors.grey[400],
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: Colors.blue[600]!, width: 2),
                    ),
                  ),
                ),
              ),
              if (isAuto)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  onPressed: onGenerate,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: isAuto,
              onChanged: isLoading ? null : onToggle,
              activeColor: Colors.blue[600],
            ),
            Text(
              'Auto-generate $hint',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const Spacer(),
            if (isAuto)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Prefix: $prefix',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
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
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your password';
          }
          if (value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
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
}
