import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartpay/config/counties.dart' show CountyConfig;
import 'package:smartpay/model/county.dart' show County;

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final String meterNumber;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.meterNumber,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late User _currentUser;
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _accountData = {};
  final Map<String, dynamic> _usageData = {};
  bool _isLoading = true;
  bool _isEditing = false;

  // Text editing controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // County related variables
  String? _selectedCounty;
  List<County> _counties = [];
  Map<String, County> _countiesMap = {};

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
    _loadCounties();
    _initializeData();
  }

  void _loadCounties() {
    // Load all counties from CountyConfig
    _counties = CountyConfig.getAllCounties();
    _countiesMap = {};
    for (var county in _counties) {
      _countiesMap[county.code] = county;
    }
  }

  Future<void> _initializeData() async {
    try {
      await _loadAllUserData();
    } catch (e) {
      print('Error initializing data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllUserData() async {
    try {
      // Get user document from users collection
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(widget.userId).get();

      if (userDoc.exists) {
        _userData = userDoc.data() as Map<String, dynamic>;

        // Set selected county
        _selectedCounty = _userData['county'];

        // Get account details
        DocumentSnapshot accountDoc = await _firestore
            .collection('account_details')
            .doc(widget.userId)
            .get();
        if (accountDoc.exists) {
          _accountData = accountDoc.data() as Map<String, dynamic>;
        }

        // Update controllers with Firestore data
        _nameController.text = _userData['name'] ?? widget.userName;
        _phoneController.text = _userData['phone'] ?? '';
        _idNumberController.text = _userData['idNumber'] ?? '';
        _addressController.text = _userData['address'] ?? '';
        _locationController.text = _userData['location'] ?? '';

        setState(() {
          _isLoading = false;
        });

        print('✅ All user data loaded successfully');
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserData() async {
    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your name');
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your phone number');
      return;
    }

    if (_idNumberController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your ID number');
      return;
    }

    if (_selectedCounty == null) {
      _showErrorDialog('Please select your county');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'idNumber': _idNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'location': _locationController.text.trim(),
        'county': _selectedCounty,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update users collection
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .update(updatedData);

      // Update account_details collection
      await _firestore.collection('account_details').doc(widget.userId).update({
        ...updatedData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update clients collection
      await _firestore.collection('clients').doc(widget.meterNumber).update({
        'name': updatedData['name'],
        'phone': updatedData['phone'],
        'idNumber': updatedData['idNumber'],
        'address': updatedData['address'],
        'location': updatedData['location'],
        'county': updatedData['county'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update county_details collection
      await _updateCountyDetails(updatedData);

      print('✅ All collections updated successfully');

      // Reload data to get updated information
      await _loadAllUserData();

      setState(() {
        _isEditing = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error updating profile. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateCountyDetails(Map<String, dynamic> userData) async {
    try {
      final county = _countiesMap[_selectedCounty!];
      if (county == null) return;

      // Create or update county_details document
      // Structure: county_details/{countyCode}/users/{userId}
      final countyDetailsRef = _firestore
          .collection('county_details')
          .doc(_selectedCounty)
          .collection('users')
          .doc(widget.userId);

      final countyUserData = {
        'userId': widget.userId,
        'name': userData['name'],
        'email': widget.userEmail,
        'meterNumber': widget.meterNumber,
        'phone': userData['phone'],
        'idNumber': userData['idNumber'],
        'address': userData['address'],
        'location': userData['location'],
        'accountNumber': _userData['accountNumber'] ?? 'Not assigned',
        'county': _selectedCounty,
        'countyName': county.name,
        'joinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await countyDetailsRef.set(countyUserData, SetOptions(merge: true));

      // Also update the county summary document
      final countySummaryRef =
          _firestore.collection('county_details').doc(_selectedCounty);

      // Get current count
      final usersSnapshot =
          await countySummaryRef.collection('users').count().get();

      await countySummaryRef.set({
        'countyName': county.name,
        'totalUsers': usersSnapshot.count,
        'waterRate': county.waterRate,
        'waterProvider': county.waterProvider,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ County details updated successfully');
    } catch (e) {
      print('❌ Error updating county details: $e');
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _cancelEdit() {
    // Reset controllers to original values from Firestore
    _nameController.text = _userData['name'] ?? widget.userName;
    _phoneController.text = _userData['phone'] ?? '';
    _idNumberController.text = _userData['idNumber'] ?? '';
    _addressController.text = _userData['address'] ?? '';
    _locationController.text = _userData['location'] ?? '';
    _selectedCounty = _userData['county'];

    setState(() {
      _isEditing = false;
    });
  }

  void _showCountySelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Select Your County',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search counties...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        // Implement search functionality if needed
                      },
                    ),
                  ),

                  // Counties List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _counties.length,
                      itemBuilder: (context, index) {
                        final county = _counties[index];
                        final isSelected = _selectedCounty == county.code;
                        final primaryColor =
                            _getPrimaryColorForCounty(county.code);

                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: primaryColor.withOpacity(0.1),
                              image: county.countyLogo.isNotEmpty
                                  ? DecorationImage(
                                      image: AssetImage(county.countyLogo),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: county.countyLogo.isEmpty
                                ? Icon(
                                    Icons.location_city,
                                    color: primaryColor,
                                  )
                                : null,
                          ),
                          title: Text(
                            county.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                county.waterProvider,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.attach_money,
                                      size: 12, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    'KES ${county.waterRate.toStringAsFixed(2)}/litre',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: primaryColor)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedCounty = county.code;
                            });
                            Future.delayed(const Duration(milliseconds: 300),
                                () {
                              Navigator.pop(context);
                            });
                          },
                        );
                      },
                    ),
                  ),

                  // Current Selection
                  if (_selectedCounty != null &&
                      _countiesMap.containsKey(_selectedCounty))
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getPrimaryColorForCounty(_selectedCounty!)
                            .withOpacity(0.1),
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: _getPrimaryColorForCounty(_selectedCounty!)
                                  .withOpacity(0.2),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.check_circle,
                                color:
                                    _getPrimaryColorForCounty(_selectedCounty!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected: ${_countiesMap[_selectedCounty]!.name}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getPrimaryColorForCounty(
                                        _selectedCounty!),
                                  ),
                                ),
                                Text(
                                  'Water Rate: KES ${_countiesMap[_selectedCounty]!.waterRate.toStringAsFixed(2)}/litre',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
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
      return Colors.blueAccent;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Validation Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    _addressController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Colors.blueAccent,
                ),
              ),
              onPressed: _toggleEditMode,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading your profile...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Header
                  _buildProfileHeader(),
                  const SizedBox(height: 32),

                  // Account Information Section
                  _buildAccountInfoSection(),
                  const SizedBox(height: 24),

                  // Personal Details Section
                  _buildSectionTitle('Personal Details'),
                  const SizedBox(height: 16),

                  // Information message about data storage
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue[700], size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isEditing
                                ? "Your information will be saved to your account"
                                : "Your profile information is securely stored",
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Editable Form Fields
                  _buildEditableForm(),

                  // County Selection
                  if (_isEditing) ...[
                    const SizedBox(height: 16),
                    _buildCountySelection(),
                  ],

                  const SizedBox(height: 24),

                  // Action Buttons when editing
                  if (_isEditing) _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final accountNumber = _userData['accountNumber'] ?? 'Not assigned';
    final countyName =
        _selectedCounty != null && _countiesMap.containsKey(_selectedCounty)
            ? _countiesMap[_selectedCounty]!.name
            : 'County not set';

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF667eea),
                    Color(0xFF764ba2),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                size: 50,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          _nameController.text.isNotEmpty
              ? _nameController.text
              : widget.userName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.userEmail,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Acc: $accountNumber',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Mtr: ${widget.meterNumber}',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_selectedCounty != null &&
                _countiesMap.containsKey(_selectedCounty))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPrimaryColorForCounty(_selectedCounty!)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  countyName,
                  style: TextStyle(
                    color: _getPrimaryColorForCounty(_selectedCounty!),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Active Account',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountInfoSection() {
    final accountNumber = _userData['accountNumber'] ?? 'Not assigned';
    final meterNumber = _userData['meterNumber'] ?? widget.meterNumber;
    final idNumber = _userData['idNumber'] ?? 'Not set';
    final countyName =
        _selectedCounty != null && _countiesMap.containsKey(_selectedCounty)
            ? _countiesMap[_selectedCounty]!.name
            : 'Not set';
    final createdAt = _userData['createdAt'] != null
        ? (_userData['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_circle_outlined, size: 20),
              SizedBox(width: 8),
              Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Meter Number', meterNumber, Icons.speed),
          const SizedBox(height: 12),
          _buildInfoRow('Account Number', accountNumber, Icons.account_balance),
          const SizedBox(height: 12),
          _buildInfoRow('ID Number', idNumber, Icons.badge),
          const SizedBox(height: 12),
          _buildInfoRow('County', countyName, Icons.location_city),
          const SizedBox(height: 12),
          _buildInfoRow(
              'Member Since',
              '${createdAt.day}/${createdAt.month}/${createdAt.year}',
              Icons.calendar_today),
        ],
      ),
    );
  }

  Widget _buildCountySelection() {
    final currentCounty =
        _selectedCounty != null && _countiesMap.containsKey(_selectedCounty)
            ? _countiesMap[_selectedCounty]!
            : null;
    final primaryColor = currentCounty != null
        ? _getPrimaryColorForCounty(currentCounty.code)
        : Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.location_city, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'County *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _showCountySelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              currentCounty?.name ?? 'Select your county',
                              style: TextStyle(
                                fontSize: 14,
                                color: currentCounty != null
                                    ? Colors.black87
                                    : Colors.grey[400],
                                fontStyle: currentCounty == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (currentCounty != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.water_drop, size: 16, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Water Rate: KES ${currentCounty.waterRate.toStringAsFixed(2)}/litre',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            currentCounty.waterProvider,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.teal),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Icon(icon, size: 16, color: Colors.grey[600]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: value == 'Not set' || value == 'Not assigned'
                  ? Colors.grey[500]
                  : Colors.black87,
              fontStyle: value == 'Not set' || value == 'Not assigned'
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        const Icon(Icons.person_outline, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        if (!_isEditing)
          Text(
            'Tap edit icon to update',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
      ],
    );
  }

  Widget _buildEditableForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEditableField(
            icon: Icons.person_outline,
            label: 'Full Name *',
            controller: _nameController,
            hintText: 'Enter your full name',
            isEditable: _isEditing,
          ),
          _buildDivider(),
          _buildEditableField(
            icon: Icons.phone_outlined,
            label: 'Mobile Number *',
            controller: _phoneController,
            hintText: 'Enter your mobile number',
            isEditable: _isEditing,
            keyboardType: TextInputType.phone,
          ),
          _buildDivider(),
          _buildEditableField(
            icon: Icons.badge_outlined,
            label: 'ID Number *',
            controller: _idNumberController,
            hintText: 'Enter your identification number',
            isEditable: _isEditing,
            keyboardType: TextInputType.number,
          ),
          _buildDivider(),
          _buildEditableField(
            icon: Icons.home_outlined,
            label: 'Address',
            controller: _addressController,
            hintText: 'Enter your complete address',
            isEditable: _isEditing,
            maxLines: 2,
          ),
          _buildDivider(),
          _buildEditableField(
            icon: Icons.location_on_outlined,
            label: 'Location',
            controller: _locationController,
            hintText: 'Enter your city/town',
            isEditable: _isEditing,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String hintText,
    required bool isEditable,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                isEditable
                    ? TextField(
                        controller: controller,
                        keyboardType: keyboardType,
                        maxLines: maxLines,
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      )
                    : Text(
                        controller.text.isNotEmpty
                            ? controller.text
                            : 'Not set',
                        style: TextStyle(
                          fontSize: 14,
                          color: controller.text.isNotEmpty
                              ? Colors.grey[700]
                              : Colors.grey[400],
                          fontStyle: controller.text.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        color: Colors.grey[200],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Text(
          '* Required field',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancelEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
