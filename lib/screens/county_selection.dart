import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartpay/config/counties.dart';
import 'package:smartpay/model/county.dart' show County;
import 'package:smartpay/screens/dashboard.dart';

class CountySelectionScreen extends StatefulWidget {
  final String userId;
  final String meterNumber;
  final String userName;
  final String userEmail;

  const CountySelectionScreen({
    super.key,
    required this.userId,
    required this.meterNumber,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<CountySelectionScreen> createState() => _CountySelectionScreenState();
}

class _CountySelectionScreenState extends State<CountySelectionScreen> {
  String? _selectedCounty;
  bool _isLoading = false;
  late final Map<String, List<County>> _countiesByRegion;

  @override
  void initState() {
    super.initState();
    _countiesByRegion = _buildCountiesByRegion();
    _loadSavedCounty();
  }

  Future<void> _loadSavedCounty() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCounty = prefs.getString('user_county');

    if (savedCounty != null && CountyConfig.counties.containsKey(savedCounty)) {
      _navigateToDashboard(savedCounty);
    }
  }

  // Build a map of region -> list of counties from CountyConfig.counties
  Map<String, List<County>> _buildCountiesByRegion() {
    final Map<String, List<County>> grouped = {};

    for (final entry in CountyConfig.counties.entries) {
      final county = entry.value;
      final countyCode = entry.key;

      // Try different ways to get the region
      String region = 'Unknown';

      // Method 1: Check if county has a region property (as field/variable)
      try {
        // First check if it's accessible as a property
        // If County class has a region field, use reflection or manual checking
        // Since we can't know the exact structure, let's try different approaches

        // Approach 1: Check if there's a 'region' field in the theme
        if (county.theme.containsKey('region')) {
          region = county.theme['region']?.toString() ?? 'Unknown';
        }
        // Approach 2: Create regions based on county name
        else if (county.name.toLowerCase().contains('nairobi')) {
          region = 'Nairobi Region';
        } else if (county.name.toLowerCase().contains('kisumu') ||
            county.name.toLowerCase().contains('kisii')) {
          region = 'Nyanza Region';
        } else if (county.name.toLowerCase().contains('mombasa') ||
            county.name.toLowerCase().contains('kilifi')) {
          region = 'Coastal Region';
        } else if (county.name.toLowerCase().contains('nakuru') ||
            county.name.toLowerCase().contains('naivasha')) {
          region = 'Rift Valley Region';
        } else if (county.name.toLowerCase().contains('kiambu') ||
            county.name.toLowerCase().contains('thika')) {
          region = 'Central Region';
        } else if (county.name.toLowerCase().contains('kakamega') ||
            county.name.toLowerCase().contains('bungoma')) {
          region = 'Western Region';
        } else if (county.name.toLowerCase().contains('machakos') ||
            county.name.toLowerCase().contains('kitui')) {
          region = 'Eastern Region';
        } else {
          region = 'Other Regions';
        }
      } catch (e) {
        print('Error getting region for county ${county.name}: $e');
        region = 'Other Regions';
      }

      grouped.putIfAbsent(region, () => []).add(county);
    }

    return grouped;
  }

  Future<void> _saveCountyAndContinue(String countyCode) async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_county', countyCode);

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'county': countyCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update client record
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(widget.meterNumber)
          .update({
        'county': countyCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _navigateToDashboard(countyCode);
    } catch (e) {
      print('Error saving county: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToDashboard(String countyCode) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Dashboard(
          userId: widget.userId,
          meterNumber: widget.meterNumber,
          userName: widget.userName,
          userEmail: widget.userEmail,
          countyCode: countyCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.water_drop,
                        size: 40,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SmartPay',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      Text(
                        'Kenya Water Management',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text(
                      'Select Your County',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose your county to access local water rates and payment methods',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // County Selection by Region
                    if (_countiesByRegion.isNotEmpty)
                      ..._countiesByRegion.entries.map((entry) {
                        return _buildRegionSection(entry.key, entry.value);
                      })
                    else
                      const Center(
                        child: Text('No counties available'),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Continue Button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedCounty != null && !_isLoading
                      ? () => _saveCountyAndContinue(_selectedCounty!)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedCounty != null
                        ? _getPrimaryColorForCounty(_selectedCounty!)
                        : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _selectedCounty != null
                              ? 'Continue to ${CountyConfig.getCounty(_selectedCounty!).name}'
                              : 'Select County',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionSection(String regionName, List<County> counties) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Region Header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            regionName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        // Counties Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: counties.length,
          itemBuilder: (context, index) {
            return _buildCountyCard(counties[index]);
          },
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCountyCard(County county) {
    final isSelected = _selectedCounty == county.code;
    final primaryColor = _getPrimaryColorForCounty(county.code);

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? primaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedCounty = county.code),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // County Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: primaryColor.withOpacity(0.1),
                    ),
                    child: Center(
                      child: county.countyLogo.isNotEmpty
                          ? Image.asset(
                              county.countyLogo,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.location_city,
                                size: 20,
                                color: primaryColor,
                              ),
                            )
                          : Icon(
                              Icons.location_city,
                              size: 20,
                              color: primaryColor,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      county.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: primaryColor,
                      size: 20,
                    ),
                ],
              ),

              // Water Rate
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'KES ${county.waterRate}/litre',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ),

              // Water Provider
              Text(
                county.waterProvider,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Payment Methods
              Row(
                children: [
                  const Icon(Icons.payment, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getEnabledPaymentMethods(county),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPrimaryColorForCounty(String countyCode) {
    try {
      final county = CountyConfig.getCounty(countyCode);
      final colorString = county.theme['primaryColor']?.toString() ?? '#2196F3';
      return Color(
        int.parse(colorString.replaceFirst('#', '0xFF')),
      );
    } catch (e) {
      return Colors.blueAccent; // Fallback color
    }
  }

  String _getEnabledPaymentMethods(County county) {
    try {
      return county.paymentMethods.entries
          .where((entry) => entry.value['enabled'] == true)
          .map((entry) => entry.value['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .join(', ');
    } catch (e) {
      return 'M-Pesa'; // Default payment method
    }
  }
}
