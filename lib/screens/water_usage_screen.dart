import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartpay/model/payment_model.dart';
import 'package:smartpay/screens/paybill_screen.dart';

class WaterUsageScreen extends StatefulWidget {
  final String meterNumber;
  final String userId;
  final String countyCode; // Added countyCode

  const WaterUsageScreen({
    super.key,
    required this.meterNumber,
    required this.userId,
    required this.countyCode, // Make required
  });

  @override
  State<WaterUsageScreen> createState() => _WaterUsageScreenState();
}

class _WaterUsageScreenState extends State<WaterUsageScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  List<Payment> _paymentHistory = [];
  bool _isLoading = true;
  double _remainingLitres = 0.0;
  double _totalLitresPurchased = 0.0;
  double _waterUsed = 0.0;
  String _countyName = '';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _clientSubscription;
  StreamSubscription? _paymentsSubscription;

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
    _setupRealTimeListeners();
  }

  void _setupRealTimeListeners() {
    print('🎯 Setting up real-time listeners for meter: ${widget.meterNumber}');

    if (widget.meterNumber.isEmpty) {
      print('❌ Meter number is empty');
      setState(() => _isLoading = false);
      return;
    }

    _clientSubscription = _firestore
        .collection('clients')
        .doc(widget.meterNumber)
        .snapshots()
        .listen((DocumentSnapshot snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _updateClientData(snapshot.data() as Map<String, dynamic>);
      } else {
        print('⚠️ No client document found for meter: ${widget.meterNumber}');
        setState(() => _isLoading = false);
      }
    }, onError: (error) {
      print('❌ Client stream error: $error');
      setState(() => _isLoading = false);
    });

    _paymentsSubscription = _firestore
        .collection('payments')
        .where('meterNumber', isEqualTo: widget.meterNumber)
        .where('processed', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((QuerySnapshot snapshot) {
      _updatePaymentData(snapshot.docs);
    }, onError: (error) {
      print('❌ Payments stream error: $error');
    });
  }

  void _updateClientData(Map<String, dynamic> clientData) {
    if (mounted) {
      setState(() {
        _remainingLitres = (clientData['remainingLitres'] ??
                clientData['remainingUnits'] ??
                0.0)
            .toDouble();
        _totalLitresPurchased = (clientData['totalLitresPurchased'] ??
                clientData['totalUnitsPurchased'] ??
                0.0)
            .toDouble();
        _waterUsed = (clientData['waterUsed'] ?? 0.0).toDouble();
        _countyName = clientData['county']?.toString() ?? '';

        print('🔄 Client Data Updated:');
        print('   - Remaining Litres: $_remainingLitres');
        print('   - Total Purchased: $_totalLitresPurchased');
        print('   - Water Used: $_waterUsed');

        _isLoading = false;
      });

      final remainingBalance = _calculateRemainingBalance();
      _publishToDashboardData(remainingBalance);

      if (_totalLitresPurchased > 0) {
        final remainingPercent =
            (_remainingLitres / _totalLitresPurchased).clamp(0.0, 1.0);
        _animation = Tween<double>(begin: 0, end: remainingPercent).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
        _controller.forward(from: 0);
      }
    }
  }

  void _publishToDashboardData(double remainingBalance) {
    try {
      if (widget.userId.isEmpty) {
        print('⚠️ User ID is empty, skipping dashboard update');
        return;
      }

      _firestore.collection('dashboard_data').doc(widget.userId).set({
        'remainingBalance': remainingBalance,
        'waterUsed': _waterUsed,
        'totalPurchased': _totalLitresPurchased,
        'meterNumber': widget.meterNumber,
        'countyCode': widget.countyCode,
        'countyName': _countyName,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _firestore.collection('users').doc(widget.userId).update({
        'currentRemainingBalance': remainingBalance,
        'currentWaterUsed': _waterUsed,
        'lastWaterUpdate': FieldValue.serverTimestamp(),
      });

      print('📤 Published to dashboard_data: $remainingBalance litres');
    } catch (e) {
      print('❌ Error publishing to dashboard: $e');
    }
  }

  void _updatePaymentData(List<QueryDocumentSnapshot> paymentDocs) {
    if (mounted) {
      setState(() {
        _paymentHistory = paymentDocs
            .map((doc) => Payment.fromQueryDoc(doc))
            .where((payment) => payment.isSuccessful)
            .toList();

        double paymentTotal = _paymentHistory.fold(
            0.0, (sum, payment) => sum + payment.litresPurchased);

        print('💰 Payment Data Updated:');
        print('   - Total Payments: ${_paymentHistory.length}');
        print('   - Total from Payments: $paymentTotal');

        if (_totalLitresPurchased == 0 && paymentTotal > 0) {
          _totalLitresPurchased = paymentTotal;
          print(
              '🔄 Using payment data as fallback: $_totalLitresPurchased litres');
        }
      });
    }
  }

  double _calculateRemainingBalance() {
    if (_remainingLitres > 0) {
      return _remainingLitres;
    }
    return (_totalLitresPurchased - _waterUsed).clamp(0.0, double.infinity);
  }

  String _calculateDaysLeft() {
    final remainingBalance = _calculateRemainingBalance();
    if (remainingBalance <= 0) return '0';

    final averageDailyUsage = _waterUsed > 0 ? _waterUsed / 30 : 10.0;
    final daysLeft = remainingBalance / averageDailyUsage;
    return daysLeft.floor().toString();
  }

  @override
  void dispose() {
    _clientSubscription?.cancel();
    _paymentsSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color _getCircleColor(double value) {
    if (value < 0.33) return const Color(0xFFFF3B30);
    if (value < 0.66) return const Color(0xFFFF9500);
    return const Color(0xFF34C759);
  }

  void _navigateToBuyUnits() {
    // FIXED: Pass both userId and countyCode
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PayBillScreen(
          meterNumber: widget.meterNumber,
          userId: widget.userId,
          countyCode: widget.countyCode, // Now passing countyCode
        ),
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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${payment.litresPurchased.toStringAsFixed(2)} litres'),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your water usage data...'),
            ],
          ),
        ),
      );
    }

    final remainingBalance = _calculateRemainingBalance();
    final remainingPercent = _totalLitresPurchased > 0
        ? (remainingBalance / _totalLitresPurchased).clamp(0.0, 1.0)
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
                      Text('Meter Number: ${widget.meterNumber}'),
                      Text('County Code: ${widget.countyCode}'),
                      Text('County Name: $_countyName'),
                      const SizedBox(height: 8),
                      Text(
                          'Total Purchased: ${_totalLitresPurchased.toStringAsFixed(2)} litres'),
                      Text(
                          'Water Used: ${_waterUsed.toStringAsFixed(2)} litres'),
                      Text(
                          'Remaining Balance: ${remainingBalance.toStringAsFixed(2)} litres'),
                      Text(
                          'Payment History: ${_paymentHistory.length} transactions'),
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
            _buildSummaryCard(remainingBalance, daysLeft),
            const SizedBox(height: 32),
            _buildProgressSection(remainingPercent),
            const SizedBox(height: 32),
            _buildUsageStats(remainingBalance),
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
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
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
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  '${remainingBalance.toStringAsFixed(2)} litres',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimated $daysLeft days left',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.water_drop, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(double remainingPercent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Usage Progress',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        const SizedBox(height: 8),
        Text('Track your water consumption',
            style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
                  offset: const Offset(0, 4))
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
                          Container(
                              height: 16,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10))),
                          Container(
                              height: 16,
                              width: barWidth * _animation.value,
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    const Color(0xFFFF3B30),
                                    const Color(0xFFFF9500),
                                    const Color(0xFF34C759)
                                  ], stops: const [
                                    0.0,
                                    0.5,
                                    1.0
                                  ]),
                                  borderRadius: BorderRadius.circular(10))),
                          Positioned(
                              left: circlePos - 20,
                              child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: circleColor,
                                      border: Border.all(
                                          color: Colors.white, width: 4),
                                      boxShadow: [
                                        BoxShadow(
                                            color: circleColor.withOpacity(0.5),
                                            blurRadius: 12,
                                            spreadRadius: 3)
                                      ]),
                                  child: Icon(Icons.water_drop,
                                      color: Colors.white, size: 20))),
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
                    Column(children: [
                      Icon(Icons.warning_amber,
                          color: Color(0xFFFF3B30), size: 20),
                      SizedBox(height: 6),
                      Text("Low",
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87))
                    ]),
                    Column(children: [
                      Icon(Icons.trending_up,
                          color: Color(0xFFFF9500), size: 20),
                      SizedBox(height: 6),
                      Text("Moderate",
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87))
                    ]),
                    Column(children: [
                      Icon(Icons.check_circle,
                          color: Color(0xFF34C759), size: 20),
                      SizedBox(height: 6),
                      Text("Full",
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87))
                    ]),
                  ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsageStats(double remainingBalance) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Usage Statistics',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        const SizedBox(height: 16),
        _buildStatRow(
            'Total Purchased',
            '${_totalLitresPurchased.toStringAsFixed(2)} litres',
            Icons.shopping_cart),
        const SizedBox(height: 12),
        _buildStatRow('Water Used', '${_waterUsed.toStringAsFixed(2)} litres',
            Icons.water_drop),
        const SizedBox(height: 12),
        _buildStatRow(
            'Remaining Balance',
            '${remainingBalance.toStringAsFixed(2)} litres',
            Icons.account_balance_wallet),
        const SizedBox(height: 12),
        _buildStatRow('Payment History',
            '${_paymentHistory.length} transactions', Icons.receipt),
      ]),
    );
  }

  Widget _buildStatRow(String title, String value, IconData icon) {
    return Row(children: [
      Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.blue, size: 20)),
      const SizedBox(width: 12),
      Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87))),
      Text(value,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue)),
    ]);
  }

  Widget _buildActionButtons() {
    return Column(children: [
      const Text('Quick Actions',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87)),
      const SizedBox(height: 8),
      Text('Manage your water account',
          style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      const SizedBox(height: 20),
      _buildActionButton(
          icon: Icons.shopping_cart_outlined,
          title: 'Buy Water',
          subtitle: 'Purchase additional water litres',
          onTap: _navigateToBuyUnits,
          color: const Color(0xFF667eea)),
      const SizedBox(height: 16),
      _buildActionButton(
          icon: Icons.receipt_long_outlined,
          title: 'View Statement',
          subtitle: 'Check your billing history',
          onTap: _viewStatement,
          color: const Color(0xFF34C759)),
      const SizedBox(height: 16),
      _buildActionButton(
          icon: Icons.notifications_outlined,
          title: 'Set Usage Alert',
          subtitle: 'Get notified when balance is low',
          onTap: _setUsageAlert,
          color: const Color(0xFFFF9500)),
    ]);
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      required Color color}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 26)),
            const SizedBox(width: 18),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]))
                ])),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.arrow_forward_ios_rounded,
                    size: 18, color: Colors.grey[600])),
          ]),
        ),
      ),
    );
  }
}
