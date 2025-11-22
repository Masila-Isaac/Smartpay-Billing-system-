import 'package:flutter/material.dart';
import 'package:smartpay/screens/paybill_screen.dart';
import 'package:smartpay/screens/viewreport.dart';
import 'package:smartpay/screens/water_usage_screen.dart';
import 'package:smartpay/screens/water_reading_screen.dart';
import 'package:smartpay/screens/profile_screen.dart';
import 'package:smartpay/screens/settings_screen.dart';
import 'package:smartpay/screens/notifications_screen.dart';
import 'package:smartpay/screens/help_support_screen.dart';
import 'package:smartpay/services/auth_service.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with 3-dot menu
            _buildHeader(context),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Professional Banner with image background
                    _buildProfessionalBanner(),
                    const SizedBox(height: 32),

                    // Main Actions
                    _buildMenuButton(
                      context,
                      "Units available for usage",
                      Icons.water_drop_outlined,
                      Colors.blueAccent,
                          () {
                        _navigateWithSlideTransition(context, const WaterUsageScreen(meterNumber: '12345',));
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildMenuButton(
                      context,
                      "Make Payments",
                      Icons.payment_outlined,
                      Colors.green,
                          () {
                        _navigateWithSlideTransition(context, const PayBillScreen());
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildMenuButton(
                      context,
                      "Water Reading",
                      Icons.speed_outlined,
                      Colors.orange,
                          () {
                        _navigateWithSlideTransition(context, const WaterReadingScreen());
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildMenuButton(
                      context,
                      "View Statements",
                      Icons.receipt_long_outlined,
                      Colors.purple,
                          () {
                        _navigateWithSlideTransition(context, const ViewReport());
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

  // Professional Banner Section with Image Background
  Widget _buildProfessionalBanner() {
    return Container(
      width: double.infinity,
      height: 240, // Increased height to prevent overflow
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
          // Background image with proper overlay
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
              ),
            ),
          ),

          // Dark overlay for better text readability
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

          // Content - Using ListView to prevent overflow
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Better space distribution
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CURRENT BALANCE",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "15.5 Units",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24, // Slightly smaller to fit better
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Available for usage",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11, // Smaller font
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
                        size: 24, // Smaller icon
                      ),
                    ),
                  ],
                ),

                // Usage Statistics - More compact
                Container(
                  padding: const EdgeInsets.all(12), // Reduced padding
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
                        "2,450 L",
                        Icons.water_damage_outlined,
                      ),
                      Container(
                        height: 30, // Smaller divider
                        width: 1,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _buildBannerStat(
                        "Remaining",
                        "7,550 L",
                        Icons.inventory_2_outlined,
                      ),
                    ],
                  ),
                ),

                // Progress Bar Section
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
                            fontSize: 10, // Smaller font
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          "24.5% Used",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11, // Smaller font
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 5, // Thinner progress bar
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 25,
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
                            flex: 75,
                            child: Container(
                              color: Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Banner Stat Widget - More compact
  Widget _buildBannerStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4), // Reduced padding
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16, // Smaller icon
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14, // Smaller font
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10, // Smaller font
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Smooth slide transition navigation
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

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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

  // Smooth fade transition for menu items
  void _navigateWithFadeTransition(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  // Header with 3-dot menu
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
          // App Logo and Name
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

          // 3-dot menu
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
                    Icon(Icons.notifications_outlined, size: 20, color: Colors.black54),
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
                    Icon(Icons.settings_outlined, size: 20, color: Colors.black54),
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

  // Professional Menu Button
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

  // Handle menu selection with smooth transitions
  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'profile':
        _navigateWithSlideTransition(context, const ProfileScreen());
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

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feature coming soon!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  // Logout confirmation dialog
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
                          // Add logout logic here
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