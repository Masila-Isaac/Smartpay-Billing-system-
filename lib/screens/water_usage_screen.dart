import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/model/payment_model.dart';
import 'package:smartpay/model/water_usage_model.dart';

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
  double _remainingBalance = 0.0;
  double _totalPurchased = 0.0;
  double _waterUsed = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load payment history for this user/meter
      await _loadPaymentHistory(user.uid);

      // Load water usage data
      await _loadWaterUsage();

      setState(() {
        _isLoading = false;

        // Update animation with real data
        if (_totalPurchased > 0) {
          final remainingPercent =
              (_remainingBalance / _totalPurchased).clamp(0.0, 1.0);
          _animation = Tween<double>(begin: 0, end: remainingPercent).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
        }
      });

      _controller.forward();
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPaymentHistory(String userId) async {
    try {
      final paymentsQuery = await FirebaseFirestore.instance
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('meterNumber', isEqualTo: widget.meterNumber)
          .where('processed', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .get();

      _paymentHistory = paymentsQuery.docs
          .map((doc) => Payment.fromQueryDoc(doc))
          .where((payment) => payment.isSuccessful)
          .toList();

      // Calculate total purchased units from successful payments
      _totalPurchased = _paymentHistory.fold(
          0.0, (sum, payment) => sum + payment.unitsPurchased);

      // Calculate remaining balance
      _remainingBalance = _calculateRemainingBalance();
    } catch (e) {
      print('Error loading payment history: $e');
    }
  }

  Future<void> _loadWaterUsage() async {
    try {
      final usageQuery = await FirebaseFirestore.instance
          .collection('waterUsage')
          .where('meterNumber', isEqualTo: widget.meterNumber)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (usageQuery.docs.isNotEmpty) {
        _waterUsage = WaterUsage.fromFirestore(usageQuery.docs.first);
        _waterUsed = _waterUsage?.waterUsed ?? 0.0;

        // If waterUsage has remainingUnits, use that instead of calculation
        if (_waterUsage?.remainingUnits != null &&
            _waterUsage!.remainingUnits > 0) {
          _remainingBalance = _waterUsage!.remainingUnits;
        }
      }
    } catch (e) {
      print('Error loading water usage: $e');
    }
  }

  double _calculateRemainingBalance() {
    // Priority 1: Use waterUsage remainingUnits if available
    if (_waterUsage != null && _waterUsage!.remainingUnits > 0) {
      return _waterUsage!.remainingUnits;
    }

    // Priority 2: Calculate from payments and usage
    return (_totalPurchased - _waterUsed).clamp(0.0, double.infinity);
  }

  String _calculateDaysLeft() {
    if (_remainingBalance <= 0) return '0';

    final averageDailyUsage = _waterUsed > 0
        ? _waterUsed / 30 // Assuming 30 days of data
        : 2.7; // Default average

    final daysLeft = _remainingBalance / averageDailyUsage;
    return daysLeft.floor().toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getCircleColor(double value) {
    if (value < 0.33) return const Color(0xFFFF3B30);
    if (value < 0.66) return const Color(0xFFFF9500);
    return const Color(0xFF34C759);
  }

  void _navigateToBuyUnits() {
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
                      title: Text(payment.formattedAmount),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(payment.formattedUnits),
                          Text(
                              '${payment.formattedDate} ${payment.formattedTime}'),
                        ],
                      ),
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

    final remainingPercent = _totalPurchased > 0
        ? (_remainingBalance / _totalPurchased).clamp(0.0, 1.0)
        : 0.0;
    final daysLeft = _calculateDaysLeft();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Water Usage",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black54),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 22),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Account Summary'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Total Purchased: ${_totalPurchased.toStringAsFixed(2)} L'),
                      Text('Water Used: ${_waterUsed.toStringAsFixed(2)} L'),
                      Text(
                          'Remaining: ${_remainingBalance.toStringAsFixed(2)} L'),
                      Text('Payments: ${_paymentHistory.length}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(_remainingBalance, daysLeft),
            const SizedBox(height: 32),
            _buildProgressSection(remainingPercent),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double remainingBalance, String daysLeft) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Remaining Balance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${remainingBalance.toStringAsFixed(2)} m³',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimated $daysLeft days left',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.water_drop,
              color: Colors.white,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(double remainingPercent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Usage Progress',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Track your water consumption',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      double barWidth = constraints.maxWidth;
                      double circlePos = barWidth * _animation.value;
                      Color circleColor = _getCircleColor(_animation.value);

                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          // Background track
                          Container(
                            height: 16,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),

                          // Progress fill
                          Container(
                            height: 16,
                            width: barWidth * _animation.value,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFF3B30),
                                  const Color(0xFFFF9500),
                                  const Color(0xFF34C759),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),

                          // Animated circle indicator
                          Positioned(
                            left: circlePos - 20,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: circleColor,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: circleColor.withOpacity(0.5),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.water_drop,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Icon(Icons.warning_amber,
                          color: Color(0xFFFF3B30), size: 20),
                      SizedBox(height: 6),
                      Text(
                        "Low",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Icon(Icons.trending_up,
                          color: Color(0xFFFF9500), size: 20),
                      SizedBox(height: 6),
                      Text(
                        "Moderate",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Icon(Icons.check_circle,
                          color: Color(0xFF34C759), size: 20),
                      SizedBox(height: 6),
                      Text(
                        "Full",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your water account',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.shopping_cart_outlined,
          title: 'Buy Units',
          subtitle: 'Purchase additional water units',
          onTap: _navigateToBuyUnits,
          color: const Color(0xFF667eea),
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          icon: Icons.receipt_long_outlined,
          title: 'View Statement',
          subtitle: 'Check your billing history',
          onTap: _viewStatement,
          color: const Color(0xFF34C759),
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          icon: Icons.notifications_outlined,
          title: 'Set Usage Alert',
          subtitle: 'Get notified when usage is high',
          onTap: _setUsageAlert,
          color: const Color(0xFFFF9500),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
