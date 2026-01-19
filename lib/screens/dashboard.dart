import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/screens/paybill_screen.dart';
import 'package:smartpay/screens/viewreport.dart';
import 'package:smartpay/screens/water_Reading.dart';
import 'package:smartpay/screens/water_usage_screen.dart';
import 'package:smartpay/screens/profile_screen.dart';
import 'package:smartpay/screens/settings_screen.dart';
import 'package:smartpay/screens/notifications_screen.dart';
import 'package:smartpay/screens/help_support_screen.dart';
import 'package:smartpay/services/auth_service.dart';

class Dashboard extends StatefulWidget {
  final String userId;
  final String meterNumber;
  final String userName;
  final String userEmail;

  const Dashboard({
    super.key,
    required this.userId,
    required this.meterNumber,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  double _currentReading = 0.0;
  double _remainingUnits = 0.0;
  double _totalPurchased = 0.0;
  double _unitsConsumed = 0.0;
  String _accountNumber = '';
  bool _isLoading = true;
  bool _hasValidMeterNumber = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _waterUsageSubscription;

  @override
  void initState() {
    super.initState();
    print('📱 Dashboard initialized for user: ${widget.userId}');
    print('📊 Meter Number: "${widget.meterNumber}"');

    _hasValidMeterNumber = widget.meterNumber.isNotEmpty;

    if (_hasValidMeterNumber) {
      _setupWaterUsageListener();
    } else {
      print('⚠️ No valid meter number provided');
      setState(() => _isLoading = false);
    }
  }

  void _setupWaterUsageListener() {
    print('🎯 Setting up waterUsage listener for meter: ${widget.meterNumber}');

    _waterUsageSubscription = _firestore
        .collection('waterUsage')
        .doc(widget.meterNumber)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        _updateFromWaterUsage(snapshot.data() as Map<String, dynamic>);
      } else {
        print(
            '⚠️ No waterUsage document found for meter: ${widget.meterNumber}');
        _createInitialWaterUsageDocument();
      }
    }, onError: (error) {
      print('❌ WaterUsage stream error: $error');
      setState(() => _isLoading = false);
    });
  }

  void _updateFromWaterUsage(Map<String, dynamic> waterData) {
    if (mounted) {
      setState(() {
        // Get values from waterUsage collection (your main source)
        _currentReading = (waterData['currentReading'] ?? 0.0).toDouble();
        _remainingUnits = (waterData['remainingUnits'] ?? 0.0).toDouble();
        _totalPurchased = (waterData['totalUnitsPurchased'] ?? 0.0).toDouble();
        _unitsConsumed = (waterData['unitsConsumed'] ?? 0.0).toDouble();
        _accountNumber = waterData['accountNumber'] ?? '';

        print('💧 Water Usage Data Updated:');
        print('   - Current Reading: $_currentReading L');
        print('   - Remaining Units: $_remainingUnits L');
        print('   - Total Purchased: $_totalPurchased L');
        print('   - Units Consumed: $_unitsConsumed L');
        print('   - Account Number: $_accountNumber');

        _isLoading = false;
      });

      // Sync with dashboard_data for other screens that might use it
      _syncWithDashboardData();
    }
  }

  Future<void> _createInitialWaterUsageDocument() async {
    try {
      // Try to get account number from clients collection
      String accountNumber = '';
      final clientDoc =
          await _firestore.collection('clients').doc(widget.meterNumber).get();

      if (clientDoc.exists) {
        final clientData = clientDoc.data() as Map<String, dynamic>;
        accountNumber = clientData['accountNumber'] ?? '';
      }

      // Create initial water usage document
      await _firestore.collection('waterUsage').doc(widget.meterNumber).set({
        'meterNumber': widget.meterNumber,
        'userId': widget.userId,
        'accountNumber': accountNumber,
        'currentReading': 0.0,
        'previousReading': 0.0,
        'remainingUnits': 0.0,
        'totalUnitsPurchased': 0.0,
        'unitsConsumed': 0.0,
        'lastReadingDate': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      print('✅ Created initial waterUsage document');

      // Trigger listener to get the new data
      final newDoc = await _firestore
          .collection('waterUsage')
          .doc(widget.meterNumber)
          .get();

      if (newDoc.exists) {
        _updateFromWaterUsage(newDoc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print('❌ Error creating water usage document: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncWithDashboardData() async {
    try {
      // Update dashboard_data for backward compatibility
      await _firestore.collection('dashboard_data').doc(widget.userId).set({
        'remainingBalance': _remainingUnits,
        'waterUsed': _unitsConsumed,
        'totalPurchased': _totalPurchased,
        'meterNumber': widget.meterNumber,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('📤 Synced with dashboard_data'); // guide
    } catch (e) {
      print('⚠️ Error syncing with dashboard_data: $e');
    }
  }

  String _formatWaterVolume(double litres) {
    if (litres >= 1000) {
      return '${(litres / 1000).toStringAsFixed(1)} m³';
    } else {
      return '${litres.toStringAsFixed(0)} L';
    }
  }

  double _getUsagePercentage() {
    if (_totalPurchased == 0) return 0.0;
    final percentage = (_unitsConsumed / _totalPurchased).clamp(0.0, 1.0);
    return percentage;
  }

  String _getUsagePercentageText() {
    final percentage = _getUsagePercentage() * 100;
    return '${percentage.toStringAsFixed(1)}% Used';
  }

  // Get first name from full name
  String _getFirstName() {
    if (widget.userName.isEmpty) return 'User';
    List<String> names = widget.userName.split(' ');
    return names[0]; // Return first name only
  }

  // Truncate long meter numbers
  String _formatMeterNumber(String meterNumber) {
    if (meterNumber.length <= 15) return meterNumber;
    return '${meterNumber.substring(0, 12)}...';
  }

  // Truncate long account numbers
  String _formatAccountNumber(String accountNumber) {
    if (accountNumber.isEmpty) return '';
    if (accountNumber.length <= 20) return accountNumber;
    return '${accountNumber.substring(0, 17)}...';
  }

  @override
  void dispose() {
    _waterUsageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfessionalBanner(),
                    const SizedBox(height: 32),
                    _buildMenuButton(
                      context,
                      "Units available for usage",
                      Icons.water_drop_outlined,
                      Colors.blueAccent,
                      () {
                        _navigateWithSlideTransition(
                          context,
                          WaterUsageScreen(
                            meterNumber: widget.meterNumber,
                            userId: widget.userId,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context,
                      "Make Payments",
                      Icons.payment_outlined,
                      Colors.green,
                      () {
                        _navigateWithSlideTransition(
                          context,
                          PayBillScreen(
                            meterNumber: widget.meterNumber,
                            userId: widget.userId,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context,
                      "Water Reading",
                      Icons.speed_outlined,
                      Colors.orange,
                      () {
                        _navigateWithSlideTransition(
                          context,
                          WaterReadingScreentrail(
                              meterNumber: widget.meterNumber),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context,
                      "View Statements",
                      Icons.receipt_long_outlined,
                      Colors.purple,
                      () {
                        _navigateWithSlideTransition(
                          context,
                          ViewReport(meterNumber: widget.meterNumber),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset(
                'assets/images/logo.png', // Changed to logo_white.png
                height: 80,
                errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.water_drop,
                    size: 80,
                    color: Colors.blueAccent),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SmartPay',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Welcome, ${_getFirstName()}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'Loading your dashboard...',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalBanner() {
    String displayMeterNumber = widget.meterNumber;
    if (!_hasValidMeterNumber) {
      displayMeterNumber = 'Meter number not set';
    } else {
      displayMeterNumber = _formatMeterNumber(displayMeterNumber);
    }

    return Container(
      width: double.infinity,
      height: 280, // Increased height to prevent overflow
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.4),
                BlendMode.darken,
              ),
              child: Image.asset(
                'assets/images/banner.png',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.blue.shade400,
                          Colors.blue.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "WELCOME BACK",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _getFirstName(), // Show only first name
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Meter number with better wrapping
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.speed_outlined,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 14),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      displayMeterNumber,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                              if (_accountNumber.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      'Acc: ',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        _formatAccountNumber(_accountNumber),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 10,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.water_drop_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildRealStats(),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "MONTHLY USAGE",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          _getUsagePercentageText(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildProgressBar(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealStats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildBannerStat(
              "Used",
              _formatWaterVolume(_unitsConsumed),
              Icons.water_damage_outlined,
            ),
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          Expanded(
            child: _buildBannerStat(
              "Available",
              _formatWaterVolume(_remainingUnits),
              Icons.inventory_2_outlined,
            ),
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          Expanded(
            child: _buildBannerStat(
              "Total",
              _formatWaterVolume(_totalPurchased),
              Icons.shopping_cart_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final usagePercentage = _getUsagePercentage();
    final usedWidth = usagePercentage * 100;
    final remainingWidth = 100 - usedWidth;

    return Container(
      height: 5,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Expanded(
            flex: usedWidth.round(),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF00D4FF),
                    Color(0xFF0099FF),
                  ],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Expanded(
            flex: remainingWidth.round(),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _navigateWithSlideTransition(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  'assets/images/logo.png', // Changed to  logo_white.png
                  height: 32,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.water_drop,
                        color: Colors.blueAccent);
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "SmartPay",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.more_vert,
                color: Colors.black54,
                size: 22,
              ),
            ),
            onSelected: (value) {
              _handleMenuSelection(context, value);
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Notifications'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Help & Support'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined,
                        size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_outlined, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'profile':
        _navigateWithSlideTransition(
          context,
          ProfileScreen(
            userId: widget.userId,
            userName: widget.userName,
            userEmail: widget.userEmail,
            meterNumber: widget.meterNumber,
          ),
        );
        break;
      case 'notifications':
        _navigateWithSlideTransition(context, const NotificationsScreen());
        break;
      case 'help':
        _navigateWithSlideTransition(context, const HelpSupportScreen());
        break;
      case 'settings':
        _navigateWithSlideTransition(context, const SettingsScreen());
        break;
      case 'logout':
        _showLogoutDialog(context);
        break;
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.logout_outlined,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Logout",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Are you sure you want to logout?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Close dialog
                          Navigator.of(context).pop();

                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          );

                          try {
                            // Perform logout
                            await AuthService.logout();

                            // Close loading dialog
                            Navigator.of(context, rootNavigator: true).pop();

                            // Navigate to login and clear all routes
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                              (route) => false,
                            );
                          } catch (e) {
                            // Close loading dialog
                            Navigator.of(context, rootNavigator: true).pop();

                            // Show error
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Logout failed: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "Logout",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
