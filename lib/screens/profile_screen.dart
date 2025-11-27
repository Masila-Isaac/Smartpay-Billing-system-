import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isLoading = true;
  bool _isEditing = false;

  // Text editing controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser!;
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Initialize controllers with widget data first
      _nameController.text = widget.userName;

      // Then try to load additional data from Firestore
      await _loadUserData();
    } catch (e) {
      print('Error initializing data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      // Get user document from Firestore
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(widget.userId).get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>;
          // Only update controllers if they're empty or if we have new data
          if (_nameController.text.isEmpty) {
            _nameController.text = _userData['name'] ?? widget.userName;
          }
          _phoneController.text = _userData['phone'] ?? '';
          _addressController.text = _userData['address'] ?? '';
          _locationController.text = _userData['location'] ?? '';
          _isLoading = false;
        });
      } else {
        // If user document doesn't exist, create one with basic data
        await _createUserDocument();
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createUserDocument() async {
    try {
      await _firestore.collection('users').doc(widget.userId).set({
        'name': widget.userName,
        'email': widget.userEmail,
        'meterNumber': widget.meterNumber,
        'phone': '',
        'address': '',
        'location': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reload data after creating document
      await _loadUserData();
    } catch (e) {
      print('Error creating user document: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _firestore.collection('users').doc(widget.userId).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'location': _locationController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update account_details collection as well
      await _firestore.collection('account_details').doc(widget.userId).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'location': _locationController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Reload data to get updated information
      await _loadUserData();

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
      print('Error updating user data: $e');
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

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _cancelEdit() {
    // Reset controllers to original values from Firestore or widget data
    _nameController.text = _userData['name'] ?? widget.userName;
    _phoneController.text = _userData['phone'] ?? '';
    _addressController.text = _userData['address'] ?? '';
    _locationController.text = _userData['location'] ?? '';

    setState(() {
      _isEditing = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
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
                child: Icon(
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
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
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

                  // Editable Form Fields
                  _buildEditableForm(),

                  const SizedBox(height: 24),

                  // Action Buttons when editing
                  if (_isEditing) _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
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
            if (_isEditing)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: Colors.blueAccent,
                  ),
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
          const Text(
            'Account Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Meter Number', widget.meterNumber),
          const SizedBox(height: 12),
          _buildInfoRow('User ID', widget.userId),
          const SizedBox(height: 12),
          _buildInfoRow('Email', widget.userEmail),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
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
            label: 'Full Name',
            controller: _nameController,
            hintText: 'Enter your full name',
            isEditable: _isEditing,
          ),
          _buildDivider(),
          _buildEditableField(
            icon: Icons.phone_outlined,
            label: 'Mobile Number',
            controller: _phoneController,
            hintText: 'Enter your mobile number',
            isEditable: _isEditing,
            keyboardType: TextInputType.phone,
          ),
          _buildDivider(),
          _buildEditableField(
            icon: Icons.home_outlined,
            label: 'Address',
            controller: _addressController,
            hintText: 'Enter your address',
            isEditable: _isEditing,
            maxLines: 2,
          ),
          _buildDivider(),
          _buildEditableField(
            icon: Icons.location_on_outlined,
            label: 'Location',
            controller: _locationController,
            hintText: 'Enter your location',
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
    return Row(
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    );
  }
}
