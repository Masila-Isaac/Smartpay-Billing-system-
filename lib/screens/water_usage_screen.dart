import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/mpesa_service.dart';
import '../model/payment_model.dart';
import '../model/water_usage_model.dart';

class WaterUsageScreen extends StatefulWidget {
  final String meterNumber;

  const WaterUsageScreen({super.key, required this.meterNumber});

  @override
  State<WaterUsageScreen> createState() => _WaterUsageScreenState();
}

class _WaterUsageScreenState extends State<WaterUsageScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  WaterUsage? _waterUsage;
  List<Payment> _paymentHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _loadWaterData();
  }

  Future<void> _loadWaterData() async {
    try {
      // Load water usage from Firestore
      final waterUsage = await MpesaService.getWaterUsage(widget.meterNumber);

      // Load payment history
      final payments = await MpesaService.getPaymentHistory(widget.meterNumber);

      setState(() {
        _waterUsage = waterUsage;
        _paymentHistory = payments;
        _isLoading = false;

        // Update animation with real data
        if (waterUsage != null && waterUsage.totalUnitsPurchased > 0) {
          final remainingPercent =
              waterUsage.remainingUnits / waterUsage.totalUnitsPurchased;
          _animation =
              Tween<double>(begin: 0, end: remainingPercent.clamp(0.0, 1.0))
                  .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
        }
      });

      _controller.forward();
    } catch (e) {
      print('Error loading water data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _tableCell(String text, bool isLabel) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isLabel ? FontWeight.w600 : FontWeight.w400,
          fontSize: 15,
          color: isLabel ? Colors.black87 : Colors.blue.shade700,
        ),
      ),
    );
  }

  Widget _buildButton(
      BuildContext context, String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007AFF),
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Get color based on remaining percentage
  Color _getCircleColor(double value) {
    if (value < 0.2) return Colors.red;
    if (value < 0.5) return Colors.orange;
    return Colors.green;
  }

  String _calculateDaysLeft() {
    if (_waterUsage == null || _waterUsage!.remainingUnits <= 0) return '0';

    final averageDailyUsage = _waterUsage!.waterUsed > 0
        ? _waterUsage!.waterUsed / 30 // Assuming 30 days of data
        : 2.7; // Default average

    final daysLeft = _waterUsage!.remainingUnits / averageDailyUsage;
    return daysLeft.floor().toString();
  }

  void _navigateToBuyUnits() {
    // Navigate to payment screen
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => PaymentScreen(meterNumber: widget.meterNumber),
    //   ),
    // );

    // For now, show a dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buy Water Units'),
        content:
            Text('Navigate to payment screen for meter: ${widget.meterNumber}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _viewStatement() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment History'),
        content: SizedBox(
          width: double.maxFinite,
          child: _paymentHistory.isEmpty
              ? const Text('No payment history available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _paymentHistory.length,
                  itemBuilder: (context, index) {
                    final payment = _paymentHistory[index];
                    return ListTile(
                      leading: Icon(
                        payment.isSuccessful
                            ? Icons.check_circle
                            : Icons.pending,
                        color:
                            payment.isSuccessful ? Colors.green : Colors.orange,
                      ),
                      title: Text('KES ${payment.amount.toStringAsFixed(2)}'),
                      subtitle: Text(
                          '${payment.unitsPurchased.toStringAsFixed(2)} L'),
                      trailing: Text(
                        payment.status,
                        style: TextStyle(
                          color: payment.isSuccessful
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _setUsageAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Usage Alert'),
        content: const Text(
            'You will receive notifications when your water balance is low.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Usage alert set successfully')),
              );
              Navigator.pop(context);
            },
            child: const Text('Set Alert'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final remainingUnits = _waterUsage?.remainingUnits ?? 0;
    final waterUsed = _waterUsage?.waterUsed ?? 0;
    final totalPurchased = _waterUsage?.totalUnitsPurchased ?? 0;
    final remainingPercent =
        totalPurchased > 0 ? remainingUnits / totalPurchased : 0;
    final daysLeft = _calculateDaysLeft();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Water Usage - ${widget.meterNumber}",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          // Background watermark
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: Center(
                child: Icon(
                  Icons.water_drop,
                  size: 260,
                  color: Colors.blue.shade100,
                ),
              ),
            ),
          ),

          // Foreground content
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 15),

                // Water Usage Table
                Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnWidths: const {
                    0: FlexColumnWidth(1.8),
                    1: FlexColumnWidth(1),
                  },
                  children: [
                    TableRow(children: [
                      _tableCell("Total Units Used", true),
                      _tableCell("${waterUsed.toStringAsFixed(1)} L", false),
                    ]),
                    TableRow(children: [
                      _tableCell("Average Daily Usage", true),
                      _tableCell(
                          "${(waterUsed / 30).toStringAsFixed(1)} L", false),
                    ]),
                    TableRow(children: [
                      _tableCell("Remaining Units", true),
                      _tableCell(
                          "${remainingUnits.toStringAsFixed(1)} L", false),
                    ]),
                    TableRow(children: [
                      _tableCell("Total Purchased", true),
                      _tableCell(
                          "${totalPurchased.toStringAsFixed(1)} L", false),
                    ]),
                  ],
                ),

                const SizedBox(height: 30),

                // Progress bar with moving circle
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 18),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              double barWidth = constraints.maxWidth;
                              double circlePos = barWidth * _animation.value;
                              Color circleColor =
                                  _getCircleColor(_animation.value);

                              return Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  // Background gradient bar
                                  Container(
                                    height: 16,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Colors.red,
                                          Colors.orange,
                                          Colors.green
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Animated circle indicator
                                  Positioned(
                                    left: circlePos - 14,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: circleColor,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: circleColor.withOpacity(0.5),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Low", style: TextStyle(fontSize: 13)),
                              Text("Moderate", style: TextStyle(fontSize: 13)),
                              Text("Full", style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 30),

                Text(
                  "You have ${remainingUnits.toStringAsFixed(1)} L remaining\nEstimated $daysLeft days left",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 40),

                // Buttons
                _buildButton(context, "Buy Units", _navigateToBuyUnits),
                const SizedBox(height: 16),
                _buildButton(context, "View Statement", _viewStatement),
                const SizedBox(height: 16),
                _buildButton(context, "Set Usage Alert", _setUsageAlert),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
