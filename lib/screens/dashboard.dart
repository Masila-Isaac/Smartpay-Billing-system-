import 'package:flutter/material.dart';
import 'package:smartpay/screens/paybill_screen.dart';
import 'package:smartpay/screens/water_Reading.dart';
import 'viewreport.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8EAFE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Water Billing",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // Top image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  "assets/images/waterglobe.jpg",
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              _buildMenuButton(context, "Units available for usage", () {
                Navigator.pushNamed(context, '/waterusage');
              }),
              const SizedBox(height: 12),

              _buildMenuButton(context, "Make Payments", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PayBillScreen(),
                  ),
                );
              }),
              const SizedBox(height: 12),

              _buildMenuButton(context, "Water Reading", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WaterReadingScreen(
                      meterNumber: "12345678",
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),

              _buildMenuButton(context, "View Statements", () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ViewReport(),
                  ),
                );
              }),

              const SizedBox(height: 24),

              // Bottom image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  "assets/images/waterhand.jpg",
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Button widget
  Widget _buildMenuButton(
    BuildContext context,
    String title,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
