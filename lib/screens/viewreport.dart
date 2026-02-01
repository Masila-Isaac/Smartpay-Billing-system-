import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:smartpay/model/payment_model.dart';
import 'package:smartpay/model/water_usage_model.dart';

class ViewReport extends StatefulWidget {
  final String meterNumber;

  const ViewReport({super.key, required this.meterNumber});

  @override
  State<ViewReport> createState() => _ViewReportState();
}

class _ViewReportState extends State<ViewReport> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _userData;
  List<WaterUsage> _waterUsageData = [];
  List<Payment> _paymentData = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _reportType = 'water_usage';
  String _period = '3months';
  DateTime? _accountCreatedDate;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = "Please log in to view report";
          _isLoading = false;
        });
        return;
      }

      // Fetch user data including registration date
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        _userData = userDoc.data()!;
        if (_userData!['createdAt'] != null) {
          _accountCreatedDate = (_userData!['createdAt'] as Timestamp).toDate();
        }
        _calculateDateRange();
        await _fetchReportData();
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load user data";
        _isLoading = false;
      });
    }
  }

  void _calculateDateRange() {
    final now = DateTime.now();
    setState(() {
      _endDate = now;
      switch (_period) {
        case '3months':
          _startDate = DateTime(now.year, now.month - 3, now.day);
          break;
        case '6months':
          _startDate = DateTime(now.year, now.month - 6, now.day);
          break;
        case '1year':
          _startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        case 'all':
          _startDate =
              _accountCreatedDate ?? DateTime(now.year - 1, now.month, now.day);
          break;
      }
    });
  }

  Future<void> _fetchReportData() async {
    try {
      setState(() {
        _isLoading = true;
        _waterUsageData = [];
        _paymentData = [];
      });

      if (_reportType == 'water_usage') {
        await _fetchWaterUsageReport();
      } else {
        await _fetchPaymentReport();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load report data: $e";
        _isLoading = false;
      });
    }
  }

  // query without requiring composite index immediately
  Future<void> _fetchWaterUsageReport() async {
    try {
      // Get the latest water usage document first
      final latestUsage = await _firestore
          .collection('waterUsage')
          .where('meterNumber', isEqualTo: widget.meterNumber)
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      WaterUsage? currentUsage;
      if (latestUsage.docs.isNotEmpty) {
        currentUsage = WaterUsage.fromQueryDoc(latestUsage.docs.first);
      }

      // For historical data, we need to handle differently since you don't have timestamp field
      // Based on your model, we'll use 'lastUpdated' field for filtering
      final usageQuery = await _firestore
          .collection('waterUsage')
          .where('meterNumber', isEqualTo: widget.meterNumber)
          .orderBy('lastUpdated', descending: true)
          .get();

      final allUsage =
          usageQuery.docs.map((doc) => WaterUsage.fromQueryDoc(doc)).toList();

      // Filter by date range locally
      _waterUsageData = allUsage
          .where((usage) =>
              usage.lastUpdated.isAfter(_startDate) &&
              usage.lastUpdated.isBefore(_endDate))
          .toList();

      // If no historical data but we have current usage, show it
      if (_waterUsageData.isEmpty && currentUsage != null) {
        _waterUsageData = [currentUsage];
      }
    } catch (e) {
      print("Error fetching water usage: $e");
      // If the query fails due to index, fetch without orderBy
      final usageQuery = await _firestore
          .collection('waterUsage')
          .where('meterNumber', isEqualTo: widget.meterNumber)
          .get();

      _waterUsageData = usageQuery.docs
          .map((doc) => WaterUsage.fromQueryDoc(doc))
          .toList()
        ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

      // Filter by date
      _waterUsageData = _waterUsageData
          .where((usage) =>
              usage.lastUpdated.isAfter(_startDate) &&
              usage.lastUpdated.isBefore(_endDate))
          .toList();
    }
  }

  Future<void> _fetchPaymentReport() async {
    try {
      // Try with timestamp field (from your Payment model)
      final paymentQuery = await _firestore
          .collection('payments')
          .where('meterNumber', isEqualTo: widget.meterNumber)
          .orderBy('timestamp', descending: true)
          .get();

      _paymentData =
          paymentQuery.docs.map((doc) => Payment.fromQueryDoc(doc)).toList();

      // Filter by date range
      _paymentData = _paymentData
          .where((payment) =>
              payment.timestamp.isAfter(_startDate) &&
              payment.timestamp.isBefore(_endDate))
          .toList();
    } catch (e) {
      print("Error with ordered payment query: $e");
      // Fallback: Fetch without orderBy
      final paymentQuery = await _firestore
          .collection('payments')
          .where('meterNumber', isEqualTo: widget.meterNumber)
          .get();

      _paymentData = paymentQuery.docs
          .map((doc) => Payment.fromQueryDoc(doc))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Filter by date
      _paymentData = _paymentData
          .where((payment) =>
              payment.timestamp.isAfter(_startDate) &&
              payment.timestamp.isBefore(_endDate))
          .toList();
    }
  }

  Widget _buildReportFilters() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Report Options",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Report Type Selection
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Report Type",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip(
                        label: "Water Usage",
                        selected: _reportType == 'water_usage',
                        onTap: () => _updateReportType('water_usage'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip(
                        label: "Payments",
                        selected: _reportType == 'payment',
                        onTap: () => _updateReportType('payment'),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Period Selection
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Time Period",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(
                      label: "3 Months",
                      selected: _period == '3months',
                      onTap: () => _updatePeriod('3months'),
                    ),
                    _buildFilterChip(
                      label: "6 Months",
                      selected: _period == '6months',
                      onTap: () => _updatePeriod('6months'),
                    ),
                    _buildFilterChip(
                      label: "1 Year",
                      selected: _period == '1year',
                      onTap: () => _updatePeriod('1year'),
                    ),
                    _buildFilterChip(
                      label: "All Time",
                      selected: _period == 'all',
                      onTap: () => _updatePeriod('all'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            Text(
              "Period: ${_formatDate(_startDate)} to ${_formatDate(_endDate)}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF667eea) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF667eea) : Colors.grey[300]!,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _updateReportType(String type) {
    setState(() {
      _reportType = type;
    });
    _fetchReportData();
  }

  void _updatePeriod(String period) {
    setState(() {
      _period = period;
    });
    _calculateDateRange();
    _fetchReportData();
  }

  Widget _buildWaterUsageReport() {
    if (_waterUsageData.isEmpty) {
      return _buildEmptyState(
          "No water usage data found for the selected period");
    }

    // Check if we only have current usage (not historical)
    final hasMultipleEntries = _waterUsageData.length > 1;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Water Usage Report",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 16),

            // Current Usage Summary
            if (!hasMultipleEntries)
              _buildCurrentUsageCard(_waterUsageData.first),

            // Historical Data
            if (hasMultipleEntries) ...[
              _buildWaterUsageSummary(),
              const SizedBox(height: 20),
              const Text(
                "Usage History",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._waterUsageData.map(_buildWaterUsageItem),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentUsageCard(WaterUsage usage) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: "Remaining Units",
                value: usage.formattedRemaining,
                color: _getWaterStatusColor(usage),
                icon: Icons.water_drop,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: "Total Used",
                value: usage.formattedUsed,
                color: Colors.orange,
                icon: Icons.water_damage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: "Total Purchased",
                value: usage.formattedTotal,
                color: Colors.green,
                icon: Icons.shopping_cart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: "Usage %",
                value: "${usage.usagePercentage.toStringAsFixed(1)}%",
                color: Colors.purple,
                icon: Icons.percent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getStatusBgColor(usage.status),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _getStatusIcon(usage.status),
                color: _getStatusColor(usage.status),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Status: ${usage.status.toUpperCase()}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(usage.status),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Last Updated: ${usage.formattedLastUpdated}",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildWaterUsageSummary() {
    final totalUsed = _waterUsageData.fold<double>(
        0.0, (sum, usage) => sum + usage.waterUsed);

    final totalPurchased = _waterUsageData.isNotEmpty
        ? _waterUsageData.first.totalUnitsPurchased
        : 0.0;

    final avgDailyUsage = _calculateAverageDailyUsage();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: "Total Usage",
                value: "${totalUsed.toStringAsFixed(2)} L",
                color: Colors.blue,
                icon: Icons.bar_chart,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: "Avg Daily",
                value: "${avgDailyUsage.toStringAsFixed(2)} L/day",
                color: Colors.green,
                icon: Icons.timeline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          title: "Total Purchased",
          value: "${totalPurchased.toStringAsFixed(2)} L",
          color: Colors.purple,
          icon: Icons.inventory,
        ),
      ],
    );
  }

  double _calculateAverageDailyUsage() {
    if (_waterUsageData.isEmpty) return 0.0;

    final totalDays = _endDate.difference(_startDate).inDays;
    if (totalDays == 0) return 0.0;

    final totalUsed = _waterUsageData.fold<double>(
        0.0, (sum, usage) => sum + usage.waterUsed);

    return totalUsed / totalDays;
  }

  Widget _buildWaterUsageItem(WaterUsage usage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usage.formattedLastUpdated,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  usage.formattedUsed,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Remaining: ${usage.formattedRemaining}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusBgColor(usage.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  usage.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(usage.status),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${usage.usagePercentage.toStringAsFixed(1)}% used",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentReport() {
    if (_paymentData.isEmpty) {
      return _buildEmptyState(
          "No payment records found for the selected period");
    }

    final successfulPayments =
        _paymentData.where((p) => p.isSuccessful).toList();
    final totalPaid = successfulPayments.fold<double>(
        0.0, (sum, payment) => sum + payment.amount);
    final totalUnits = successfulPayments.fold<double>(
        0.0, (sum, payment) => sum + payment.litresPurchased);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Payment Report",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 16),

            // Payment Summary
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: "Total Paid",
                    value: "KES ${totalPaid.toStringAsFixed(2)}",
                    color: Colors.green,
                    icon: Icons.payments,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: "Units Purchased",
                    value: "${totalUnits.toStringAsFixed(2)} L",
                    color: Colors.blue,
                    icon: Icons.water_drop,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: "Successful",
                    value: "${successfulPayments.length} payments",
                    color: Colors.green,
                    icon: Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: "Pending/Failed",
                    value: "${_paymentData.length - successfulPayments.length}",
                    color: Colors.orange,
                    icon: Icons.pending,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              "Payment History",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._paymentData.map(_buildPaymentItem),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentItem(Payment payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.formattedDate,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payment.reference ?? payment.transactionId,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payment.formattedAmount,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                if (payment.mpesaReceiptNumber != null)
                  Text(
                    "M-Pesa: ${payment.mpesaReceiptNumber!}",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: payment.isSuccessful
                      ? Colors.green.withOpacity(0.1)
                      : payment.isFailed
                          ? Colors.red.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  payment.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: payment.isSuccessful
                        ? Colors.green
                        : payment.isFailed
                            ? Colors.red
                            : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (payment.litresPurchased > 0)
                Text(
                  "${payment.litresPurchased.toStringAsFixed(2)} L",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                payment.formattedTime,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              Icons.inbox,
              size: 50,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyFooter() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          const Text(
            "Smartpay limited",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your reliable partner for clean water. For inquiries, contact us at support@smartpay.co.ke or call 0795 195 136.",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Report generated on ${_formatDate(DateTime.now())}",
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // Helper methods for water usage status
  Color _getWaterStatusColor(WaterUsage usage) {
    if (usage.isCritical) return Colors.red;
    if (usage.isWarning) return Colors.orange;
    if (usage.isDepleted) return Colors.grey;
    return Colors.blue;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'depleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green.withOpacity(0.1);
      case 'warning':
        return Colors.orange.withOpacity(0.1);
      case 'depleted':
        return Colors.red.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      case 'depleted':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Usage & Payment Reports",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF667eea),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReportData,
            tooltip: "Refresh Report",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 50,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchReportData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                        ),
                        child: const Text(
                          "Retry",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meter Info
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.speed,
                                  color: Colors.blue,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Meter Number",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      widget.meterNumber,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (_userData != null &&
                                        _userData!['name'] != null)
                                      Text(
                                        "Account: ${_userData!['name']}",
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
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Report Filters
                      _buildReportFilters(),

                      const SizedBox(height: 20),

                      // Report Content
                      if (_reportType == 'water_usage')
                        _buildWaterUsageReport()
                      else
                        _buildPaymentReport(),

                      const SizedBox(height: 20),

                      // Company Footer
                      _buildCompanyFooter(),
                    ],
                  ),
                ),
    );
  }
}
