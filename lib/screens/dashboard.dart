import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/config/counties.dart' show CountyConfig;
import 'package:smartpay/model/county.dart' show County;
import 'package:smartpay/screens/county_Settings.dart';
import 'package:smartpay/screens/paybill_screen.dart';
import 'package:smartpay/screens/viewreport.dart';
import 'package:smartpay/screens/water_Reading.dart';
import 'package:smartpay/screens/water_usage_screen.dart';
import 'package:smartpay/screens/profile_screen.dart';
import 'package:smartpay/screens/settings_screen.dart';
import 'package:smartpay/screens/notifications_screen.dart';
import 'package:smartpay/screens/help_support_screen.dart';
import 'package:smartpay/services/auth_service.dart' show AuthService;

class Dashboard extends StatefulWidget {
  final String userId;
  final String meterNumber;
  final String userName;
  final String userEmail;
  final String countyCode;

  const Dashboard({
    super.key,
    required this.userId,
    required this.meterNumber,
    required this.userName,
    required this.userEmail,
    required this.countyCode,
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

  late County _county;
  Color _primaryColor = Colors.blueAccent;
  Color _secondaryColor = const Color(0xFF00C2FF);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _waterUsageSubscription;

  @override
  void initState() {
    super.initState();
    print('📱 Dashboard initialized for user: ${widget.userId}');
    print('📍 County Code: ${widget.countyCode}');

    // Load county configuration
    _county = CountyConfig.getCounty(widget.countyCode);
    _primaryColor = Color(
        int.parse(_county.theme['primaryColor'].replaceFirst('#', '0xFF')));
    _secondaryColor = Color(
        int.parse(_county.theme['secondaryColor'].replaceFirst('#', '0xFF')));

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

      // Create initial water usage document with county info
      await _firestore.collection('waterUsage').doc(widget.meterNumber).set({
        'meterNumber': widget.meterNumber,
        'userId': widget.userId,
        'accountNumber': accountNumber,
        'countyCode': widget.countyCode,
        'countyName': _county.name,
        'waterRate': _county.waterRate,
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
        'countyCode': widget.countyCode,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('📤 Synced with dashboard_data');
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
                    _buildWaterRateInfo(),
                    const SizedBox(height: 24),
                    _buildMenuButton(
                      context,
                      "Units available for usage",
                      Icons.water_drop_outlined,
                      _primaryColor,
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
                      _secondaryColor,
                      () {
                        _navigateWithSlideTransition(
                          context,
                          PayBillScreen(
                            meterNumber: widget.meterNumber,
                            userId: widget.userId,
                            countyCode: widget.countyCode,
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
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset(
                'assets/images/logo.png',
                height: 80,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.water_drop,
                  size: 80,
                  color: _primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'SmartPay',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _primaryColor,
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      image: DecorationImage(
                        image: AssetImage(_county.countyLogo),
                        fit: BoxFit.cover,
                        onError: (error, stackTrace) => Container(
                          color: _primaryColor,
                          child: const Icon(
                            Icons.location_city,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _county.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            CircularProgressIndicator(
              color: _primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'Loading your dashboard...',
              style: TextStyle(
                color: _primaryColor,
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
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.15),
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
                _primaryColor.withOpacity(0.2),
                BlendMode.multiply,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _primaryColor.withOpacity(0.3),
                      _primaryColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
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
                  _primaryColor.withOpacity(0.3),
                  _primaryColor.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // County logo/badge
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      image: DecorationImage(
                        image: AssetImage(_county.countyLogo),
                        fit: BoxFit.cover,
                        onError: (error, stackTrace) => Container(
                          color: Colors.white,
                          child: Icon(
                            Icons.location_city,
                            size: 16,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _county.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                                _getFirstName(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.speed_outlined,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 14,
                                  ),
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
                                _primaryColor,
                                _secondaryColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.4),
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

  Widget _buildWaterRateInfo() {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: _primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_county.waterProvider} Water Rates',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current rate: KES ${_county.waterRate.toStringAsFixed(2)} per litre',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paybill: ${_county.paybillNumber} • Till: ${_county.tillNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
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
                gradient: LinearGradient(
                  colors: [
                    _secondaryColor,
                    _primaryColor,
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
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 32,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.water_drop,
                      color: _primaryColor,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SmartPay",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    _county.name,
                    style: TextStyle(
                      fontSize: 10,
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
              child: Icon(
                Icons.more_vert,
                color: _primaryColor,
                size: 22,
              ),
            ),
            onSelected: (value) {
              _handleMenuSelection(context, value);
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20, color: _primaryColor),
                    const SizedBox(width: 12),
                    const Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 20, color: _primaryColor),
                    const SizedBox(width: 12),
                    const Text('Notifications'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 20, color: _primaryColor),
                    const SizedBox(width: 12),
                    const Text('Help & Support'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'county_settings',
                child: Row(
                  children: [
                    Icon(Icons.location_city, size: 20, color: _primaryColor),
                    const SizedBox(width: 12),
                    const Text('County Settings'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined,
                        size: 20, color: _primaryColor),
                    const SizedBox(width: 12),
                    const Text('Settings'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_outlined, size: 20, color: Colors.red),
                    const SizedBox(width: 12),
                    const Text(
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
      case 'county_settings':
        _navigateWithSlideTransition(
          context,
          CountySettingsScreen(),
        );
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
                Icon(
                  Icons.logout_outlined,
                  size: 48,
                  color: _primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  "Logout",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
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
                          side: BorderSide(color: _primaryColor),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(color: _primaryColor),
                        ),
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
                              return Center(
                                child: CircularProgressIndicator(
                                  color: _primaryColor,
                                ),
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
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
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
