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
    if (nameController.text.isEmpty ||
        phoneController.text.isEmpty ||
        idNumberController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _showErrorDialog('Please fill in all required fields');
      return;
    }

    if (!_isMeterNumberAuto && meterNumberController.text.isEmpty) {
      _showErrorDialog('Please enter or generate a meter number');
      return;
    }

    if (!_isAccountNumberAuto && accountNumberController.text.isEmpty) {
      _showErrorDialog('Please enter or generate an account number');
      return;
    }

    if (!RegExp(r'^[0-9]{10,15}$').hasMatch(phoneController.text.trim())) {
      _showErrorDialog('Please enter a valid phone number (10-15 digits)');
      return;
    }

    if (!RegExp(r'^[0-9]{6,12}$').hasMatch(idNumberController.text.trim())) {
      _showErrorDialog(
          'Please enter a valid identification number (6-12 digits)');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(emailController.text.trim())) {
      _showErrorDialog('Please enter a valid email address');
      return;
    }

    if (passwordController.text.length < 6) {
      _showErrorDialog('Password must be at least 6 characters long');
      return;
    }

    final meterSnapshot = await _firestore
        .collection('clients')
        .where('meterNumber', isEqualTo: meterNumberController.text.trim())
        .limit(1)
        .get();

    if (meterSnapshot.docs.isNotEmpty) {
      _showErrorDialog(
          'Meter number already exists. Please generate a new one.');
      if (_isMeterNumberAuto) {
        _generateMeterNumber();
      }
      return;
    }

    final accountSnapshot = await _firestore
        .collection('account_details')
        .where('accountNumber', isEqualTo: accountNumberController.text.trim())
        .limit(1)
        .get();

    if (accountSnapshot.docs.isNotEmpty) {
      _showErrorDialog(
          'Account number already exists. Please generate a new one.');
      if (_isAccountNumberAuto) {
        _generateAccountNumber();
      }
      return;
    }

    final emailSnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: emailController.text.trim())
        .limit(1)
        .get();

    if (emailSnapshot.docs.isNotEmpty) {
      _showErrorDialog('Email already exists. Please use a different email.');
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
        print('📊 User ID: ${user.uid}');
        print('📊 Meter Number: $meterNumber');
        print('📊 Account Number: $accountNumber');

        _showSuccessDialog(meterNumber, accountNumber);
      }
    } catch (e) {
      print('❌ Sign up error: $e');
      _showErrorDialog('Sign up failed: ${e.toString()}');
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
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: phoneController,
              hint: "Phone Number",
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              prefixText: "+254 ",
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: idNumberController,
              hint: "Identification Number",
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _buildTextFieldWithToggle(
              controller: meterNumberController,
              hint: "Meter Number",
              icon: Icons.water_damage_outlined,
              isAuto: _isMeterNumberAuto,
              onToggle: _toggleMeterNumberAuto,
              onGenerate: _refreshMeterNumber,
              prefix: "MTR",
            ),
            const SizedBox(height: 20),
            _buildTextFieldWithToggle(
              controller: accountNumberController,
              hint: "Account Number",
              icon: Icons.account_balance_outlined,
              isAuto: _isAccountNumberAuto,
              onToggle: _toggleAccountNumberAuto,
              onGenerate: _refreshAccountNumber,
              prefix: "ACC",
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: emailController,
              hint: "Email Address",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
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
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hint,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: !_isLoading,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.black54),
            prefixText: prefixText,
            hintText: "Enter $hint",
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
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
        Text(
          hint,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isAuto ? Colors.grey[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAuto ? Colors.grey[200]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !_isLoading && !isAuto,
                  style: TextStyle(
                    color: isAuto ? Colors.grey[600] : Colors.black87,
                    fontWeight: isAuto ? FontWeight.w500 : FontWeight.normal,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(icon, color: Colors.black54),
                    hintText: isAuto ? 'Auto-generated' : 'Enter $hint',
                    hintStyle: TextStyle(
                      color: isAuto ? Colors.grey[500] : Colors.grey[400],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              if (isAuto)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blueAccent),
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
              onChanged: onToggle,
              activeColor: Colors.blueAccent,
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

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Password",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          enabled: !_isLoading,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
            hintText: "Enter your password",
            filled: true,
            fillColor: Colors.grey[50],
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.black54,
              ),
              onPressed: () {
                setState(() => obscurePassword = !obscurePassword);
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
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
