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
  double _waterUsed = 0.0;
  double _remainingLitres = 0.0;
  double _totalPurchased = 0.0;
  bool _isLoading = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _dashboardDataSubscription;
  StreamSubscription? _waterUsageSubscription;

  @override
  void initState() {
    super.initState();
    _setupDashboardDataListener();
    _setupWaterDataBackup();
  }

  void _setupDashboardDataListener() {
    print('📊 Setting up dashboard data listener for user: ${widget.userId}');

    _dashboardDataSubscription = _firestore
        .collection('dashboard_data')
        .doc(widget.userId)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        _updateFromDashboardData(snapshot.data() as Map<String, dynamic>);
      } else {
        print('⚠️ No dashboard data found, using backup sources');
        _setupWaterDataBackup();
      }
    }, onError: (error) {
      print('❌ Dashboard data stream error: $error');
      _setupWaterDataBackup();
    });
  }

  void _updateFromDashboardData(Map<String, dynamic> dashboardData) {
    if (mounted) {
      setState(() {
        _remainingLitres =
            (dashboardData['remainingBalance'] ?? 0.0).toDouble();
        _waterUsed = (dashboardData['waterUsed'] ?? 0.0).toDouble();
        _totalPurchased = (dashboardData['totalPurchased'] ?? 0.0).toDouble();

        print('📈 Dashboard Data Updated (from shared location):');
        print('   - Remaining Balance: $_remainingLitres L');
        print('   - Water Used: $_waterUsed L');
        print('   - Total Purchased: $_totalPurchased L');

        _isLoading = false;
      });
    }
  }

  void _setupWaterDataBackup() {
    print('🔄 Setting up backup water data listener');

    _waterUsageSubscription = _firestore
        .collection('waterUsage')
        .doc(widget.meterNumber)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        _updateFromWaterUsage(snapshot.data() as Map<String, dynamic>);
      } else {
        _setupClientsDataFallback();
      }
    }, onError: (error) {
      print('❌ WaterUsage stream error: $error');
      _setupClientsDataFallback();
    });
  }

  void _updateFromWaterUsage(Map<String, dynamic> waterData) {
    if (mounted) {
      setState(() {
        _waterUsed = (waterData['waterUsed'] ?? 0.0).toDouble();
        _remainingLitres =
            (waterData['remainingUnits'] ?? waterData['remainingLitres'] ?? 0.0)
                .toDouble();
        _totalPurchased = (waterData['totalUnitsPurchased'] ??
                waterData['totalLitresPurchased'] ??
                0.0)
            .toDouble();

        print('📊 Backup Water Data Updated from waterUsage:');
        print('   - Water Used: $_waterUsed L');
        print('   - Remaining Litres: $_remainingLitres L');
        print('   - Total Purchased: $_totalPurchased L');

        _isLoading = false;
      });
    }
  }

  void _setupClientsDataFallback() {
    _firestore.collection('clients').doc(widget.meterNumber).snapshots().listen(
        (DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        _updateFromClients(snapshot.data() as Map<String, dynamic>);
      } else {
        print('⚠️ No data found in any source');
        setState(() => _isLoading = false);
      }
    }, onError: (error) {
      print('❌ Clients stream error: $error');
      setState(() => _isLoading = false);
    });
  }

  void _updateFromClients(Map<String, dynamic> clientData) {
    if (mounted) {
      setState(() {
        _waterUsed = (clientData['waterUsed'] ?? 0.0).toDouble();
        _remainingLitres = (clientData['remainingLitres'] ??
                clientData['remainingUnits'] ??
                0.0)
            .toDouble();
        _totalPurchased = (clientData['totalLitresPurchased'] ??
                clientData['totalUnitsPurchased'] ??
                0.0)
            .toDouble();

        print('📊 Fallback Data Updated from clients:');
        print('   - Water Used: $_waterUsed L');
        print('   - Remaining Litres: $_remainingLitres L');
        print('   - Total Purchased: $_totalPurchased L');

        _isLoading = false;
      });
    }
  }

  double _calculateRemainingBalance() {
    if (_remainingLitres > 0) {
      return _remainingLitres;
    }

    final calculated =
        (_totalPurchased - _waterUsed).clamp(0.0, double.infinity);
    return calculated;
  }

  String _formatWaterVolume(double litres) {
    if (litres >= 1000) {
      return '${(litres / 1000).toStringAsFixed(1)} m³';
    } else {
      return '${litres.toStringAsFixed(0)} L';
    }
  }

  double _getUsagePercentage() {
    final total = _totalPurchased;
    if (total == 0) return 0.0;
    final used = _waterUsed;
    return (used / total).clamp(0.0, 1.0);
  }

  String _getUsagePercentageText() {
    final percentage = _getUsagePercentage() * 100;
    return '${percentage.toStringAsFixed(1)}% Used';
  }

  @override
  void dispose() {
    _dashboardDataSubscription?.cancel();
    _waterUsageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingBalance = _calculateRemainingBalance();

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
                    _buildProfessionalBanner(remainingBalance),
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
                          PayBillScreen(meterNumber: widget.meterNumber),
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

  Widget _buildProfessionalBanner(double remainingBalance) {
    return Container(
      width: double.infinity,
      height: 240,
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
                            widget.userName.split(' ')[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Meter: ${widget.meterNumber}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
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
                _isLoading
                    ? _buildLoadingStats()
                    : _buildRealStats(remainingBalance),
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
                          _isLoading ? "Loading..." : _getUsagePercentageText(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
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

  Widget _buildLoadingStats() {
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
          _buildBannerStat(
            "Volume Used",
            "Loading...",
            Icons.water_damage_outlined,
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          _buildBannerStat(
            "Remaining",
            "Loading...",
            Icons.inventory_2_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildRealStats(double remainingBalance) {
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
          _buildBannerStat(
            "Volume Used",
            _formatWaterVolume(_waterUsed),
            Icons.water_damage_outlined,
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          _buildBannerStat(
            "Remaining",
            _formatWaterVolume(remainingBalance),
            Icons.inventory_2_outlined,
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
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
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
                  'assets/images/logo.png',
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
                          Navigator.of(context).pop();
                          await AuthService.logout();
                          Navigator.pushReplacementNamed(context, '/login');
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
