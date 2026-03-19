import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend_flutter/main.dart';
import 'package:frontend_flutter/screens/auth/login.dart';
import 'package:frontend_flutter/screens/profile/verification_screen.dart';

import '../../services/api_service.dart';
import '../../services/demo_mode_service.dart';

class UserProfileScreen extends StatefulWidget {
  final bool demoMode;

  const UserProfileScreen({super.key, this.demoMode = false});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  String _name = 'User';
  String _contactNumber = 'Not available';
  String _orgEmail = 'Not available';
  String _community = 'Not set';
  String _gender = 'Not set';
  bool _isEmailVerified = false;
  bool _isIdentityVerified = false;
  bool _isDriverVerified = false;

  bool _isLoading = true;
  String? _loadError;
  String? _vehicleActionId;
  List<Map<String, dynamic>> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadProfileAndVehicles();
  }

  Future<void> _loadProfileAndVehicles() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    if (widget.demoMode) {
      final profile = DemoModeData.demoProfile();
      if (!mounted) return;
      setState(() {
        _name = profile['full_name']?.toString() ?? 'Demo User';
        _contactNumber = profile['phone_number']?.toString() ?? 'Not available';
        _orgEmail = profile['email']?.toString() ?? 'Not available';
        _community = _displayValue(profile['community']);
        _gender = _formatGender(profile['gender']?.toString());
        _isEmailVerified = profile['is_email_verified'] == true;
        _isIdentityVerified = profile['is_identity_verified'] == true;
        _isDriverVerified = profile['is_driver_verified'] == true;
        _vehicles = DemoModeData.demoVehicles();
        _isLoading = false;
        _loadError = null;
      });
      return;
    }

    final profileRes = await UserApiService.getMyProfile();
    final vehiclesRes = await VehicleApiService.getMyVehicles();

    if (!mounted) return;

    if (profileRes.success && profileRes.data is Map<String, dynamic>) {
      final profile = profileRes.data as Map<String, dynamic>;
      final vehicles = <Map<String, dynamic>>[];

      if (vehiclesRes.success && vehiclesRes.data is List) {
        for (final item in vehiclesRes.data as List) {
          if (item is Map<String, dynamic>) {
            vehicles.add(Map<String, dynamic>.from(item));
          }
        }
      }

      setState(() {
        _name = profile['full_name']?.toString() ?? 'User';
        _contactNumber = profile['phone_number']?.toString() ?? 'Not available';
        _orgEmail = profile['email']?.toString() ?? 'Not available';
        _community = _displayValue(profile['community']);
        _gender = _formatGender(profile['gender']?.toString());
        _isEmailVerified = profile['is_email_verified'] == true;
        _isIdentityVerified = profile['is_identity_verified'] == true;
        _isDriverVerified = profile['is_driver_verified'] == true;
        _vehicles = vehicles;
        _isLoading = false;
        _loadError = vehiclesRes.success
            ? null
            : (vehiclesRes.error ?? 'Unable to load vehicles.');
      });
      return;
    }

    final localProfile = await AuthService.getUserProfile();
    if (!mounted) return;

    setState(() {
      _name = localProfile['name'] ?? 'User';
      _contactNumber = localProfile['phone'] ?? 'Not available';
      _orgEmail = localProfile['email'] ?? 'Not available';
      _vehicles = [];
      _isLoading = false;
      _loadError = profileRes.error ?? 'Unable to load your profile.';
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  Future<void> _openVehicleForm({Map<String, dynamic>? vehicle}) async {
    if (widget.demoMode) {
      _showMessage(
        'Vehicle edits are read-only in Demo Mode. Use this screen to explain the verified-driver setup.',
      );
      return;
    }

    if (!_isDriverVerified) {
      _showMessage(
        'Driver verification is required before you can add vehicles.',
        isError: true,
      );
      return;
    }

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddVehicleScreen(initialData: vehicle),
      ),
    );

    if (changed == true) {
      await _loadProfileAndVehicles();
    }
  }

  Future<void> _deleteVehicle(Map<String, dynamic> vehicle) async {
    if (widget.demoMode) {
      _showMessage('Vehicle deletes are disabled in Demo Mode.');
      return;
    }

    final vehicleId = vehicle['vehicle_id']?.toString();
    if (vehicleId == null) return;

    _showWarningDialog(
      title: 'Delete Vehicle',
      content:
          'Are you sure you want to remove this vehicle from your backend profile?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
      onConfirm: () async {
        Navigator.pop(context);
        setState(() => _vehicleActionId = vehicleId);
        final res = await VehicleApiService.deleteVehicle(vehicleId);
        if (!mounted) return;
        setState(() => _vehicleActionId = null);

        if (!res.success) {
          _showMessage(
            res.error ?? 'Unable to delete this vehicle right now.',
            isError: true,
          );
          return;
        }

        _showMessage('Vehicle deleted successfully.');
        await _loadProfileAndVehicles();
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showWarningDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
    required Future<void> Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold),
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              confirmText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'User Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfileAndVehicles,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (widget.demoMode) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'Demo Mode shows a seeded profile and verified vehicle list. Actions that would change backend account data are intentionally disabled here.',
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildProfileHeader(),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 16),
              _buildVerificationButton(),
              const SizedBox(height: 20),
              _buildVehicleSection(),
              const SizedBox(height: 20),
              _buildMyAccountSection(),
              const SizedBox(height: 20),
              _buildDangerZone(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImageSource,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : null,
                  child: _profileImage == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(_orgEmail, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('4.9', 'Rating', Icons.star, Colors.green),
        _buildStatCard(
          _vehicles.length.toString(),
          'Vehicles',
          Icons.directions_car,
          Colors.blue,
        ),
        _buildStatCard('2y', 'Member', Icons.access_time, Colors.orange),
      ],
    );
  }

  Widget _buildVerificationButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildVerificationChip(
                label: _isIdentityVerified
                    ? 'Identity Verified'
                    : _isEmailVerified
                    ? 'Email Verified'
                    : 'Verification Pending',
                color: _isIdentityVerified
                    ? Colors.green
                    : _isEmailVerified
                    ? Colors.blue
                    : Colors.orange,
              ),
              _buildVerificationChip(
                label: _isDriverVerified ? 'Driver Verified' : 'Driver Locked',
                color: _isDriverVerified ? Colors.blueAccent : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        VerificationScreen(demoMode: widget.demoMode),
                  ),
                ).then((_) => _loadProfileAndVehicles());
              },
              icon: const Icon(
                Icons.verified_user_outlined,
                color: Colors.white,
              ),
              label: const Text(
                'Open Verification Center',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.directions_car,
            'My Vehicles',
            _isDriverVerified ? 'Add New' : '',
            () => _openVehicleForm(),
          ),
          const SizedBox(height: 12),
          Text(
            'This section is now synced with your backend vehicles.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          if (_loadError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Text(
                _loadError!,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_vehicles.isEmpty)
            Center(
              child: Column(
                children: [
                  Text(
                    _isDriverVerified
                        ? 'No backend vehicle added yet'
                        : 'Driver verification required before adding vehicles',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _isDriverVerified
                        ? () => _openVehicleForm()
                        : null,
                    child: const Text(
                      '+ Add Vehicle',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _vehicles.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final vehicle = _vehicles[index];
                final vehicleId = vehicle['vehicle_id']?.toString();
                final isBusy = _vehicleActionId == vehicleId;
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _vehicleTypeLabel(
                              vehicle['vehicle_type']?.toString(),
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle['vehicle_number']?.toString() ?? '',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isBusy)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: Colors.green),
                        onPressed: () => _openVehicleForm(vehicle: vehicle),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _deleteVehicle(vehicle),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMyAccountSection() {
    return Container(
      decoration: _cardDecoration(),
      child: ExpansionTile(
        leading: const Icon(Icons.account_circle, color: Colors.green),
        title: const Text(
          'My Account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Manage your backend profile details'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoTile('Contact Number', _contactNumber),
                const SizedBox(height: 12),
                _infoTile('Organization Email', _orgEmail),
                const SizedBox(height: 12),
                _infoTile('Community', _community),
                const SizedBox(height: 12),
                _infoTile('Gender', _gender),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            initialData: {
                              'name': _name,
                              'contact': _contactNumber,
                              'orgEmail': _orgEmail,
                              'community': _community == 'Not set'
                                  ? ''
                                  : _community,
                              'gender': _gender.toLowerCase() == 'not set'
                                  ? ''
                                  : _gender.toLowerCase(),
                            },
                          ),
                        ),
                      );
                      if (changed == true) {
                        await _loadProfileAndVehicles();
                      }
                    },
                    child: const Text('Edit Account Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _actionTile(Icons.logout, 'Logout', Colors.orange, () {
            _showWarningDialog(
              title: 'Logout',
              content: 'Are you sure you want to sign out?',
              confirmText: 'Logout',
              confirmColor: Colors.orange,
              onConfirm: () async {
                Navigator.pop(context);
                await AuthService.logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (route) => false,
                );
              },
            );
          }),
          const Divider(height: 1),
          _actionTile(
            Icons.pause_circle_outline,
            'Suspend Account',
            Colors.redAccent,
            () {
              _showWarningDialog(
                title: 'Suspend Account',
                content:
                    'This will hide your profile from others until you log back in. Continue?',
                confirmText: 'Suspend',
                confirmColor: Colors.redAccent,
                onConfirm: () async {
                  Navigator.pop(context);
                },
              );
            },
          ),
          const Divider(height: 1),
          _actionTile(Icons.delete_forever, 'Delete Account', Colors.red, () {
            _showWarningDialog(
              title: 'Delete Permanently',
              content:
                  'This action cannot be undone. All your data will be deleted forever.',
              confirmText: 'Delete Forever',
              confirmColor: Colors.red,
              onConfirm: () async {
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _actionTile(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    IconData icon,
    String title,
    String action,
    VoidCallback onAction,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (action.isNotEmpty)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  void _showImageSource() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final Map<String, String> initialData;

  const EditProfileScreen({super.key, required this.initialData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _communityController;
  late String _selectedGender;
  bool _isSaving = false;

  static const List<Map<String, String>> _genderOptions = [
    {'value': 'male', 'label': 'Male'},
    {'value': 'female', 'label': 'Female'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['name']);
    _communityController = TextEditingController(
      text: widget.initialData['community'],
    );
    final initialGender = widget.initialData['gender'];
    _selectedGender = ['male', 'female', 'other'].contains(initialGender)
        ? initialGender!
        : 'other';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _communityController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final res = await UserApiService.updateProfile(
      fullName: _nameController.text.trim(),
      community: _communityController.text.trim().isEmpty
          ? null
          : _communityController.text.trim(),
      gender: _selectedGender,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Unable to save profile changes.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEditField(
                label: 'Full Name',
                icon: Icons.person,
                controller: _nameController,
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildReadOnlyField(
                label: 'Contact Number',
                value: widget.initialData['contact'] ?? 'Not available',
                icon: Icons.phone,
              ),
              const SizedBox(height: 16),
              _buildReadOnlyField(
                label: 'Organization Email',
                value: widget.initialData['orgEmail'] ?? 'Not available',
                icon: Icons.school,
              ),
              const SizedBox(height: 16),
              _buildEditField(
                label: 'Community',
                icon: Icons.groups_outlined,
                controller: _communityController,
              ),
              const SizedBox(height: 16),
              Text(
                'Gender',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: _inputDecoration(Icons.wc_outlined),
                items: _genderOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option['value'],
                        child: Text(option['label']!),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGender = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Text(
                'This form saves only fields currently supported by `PUT /users/me`.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: _inputDecoration(icon),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          readOnly: true,
          decoration: _inputDecoration(icon),
        ),
      ],
    );
  }
}

class AddVehicleScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const AddVehicleScreen({super.key, this.initialData});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final RegExp _indianPlateRegExp = RegExp(
    r'^[A-Z]{2}[ -]?[0-9]{1,2}(?:[ -]?[A-Z]{1,2})?[ -]?[0-9]{4}$',
  );
  late TextEditingController _registrationController;
  String? _selectedType;
  bool _isSubmitting = false;

  static const List<Map<String, String>> _vehicleTypes = [
    {'value': '2_wheeler', 'label': 'Two Wheeler'},
    {'value': '4_wheeler', 'label': 'Four Wheeler'},
  ];

  @override
  void initState() {
    super.initState();
    _registrationController = TextEditingController(
      text: widget.initialData?['vehicle_number']?.toString() ?? '',
    );
    final initialType = widget.initialData?['vehicle_type']?.toString();
    _selectedType = ['2_wheeler', '4_wheeler'].contains(initialType)
        ? initialType
        : null;
  }

  @override
  void dispose() {
    _registrationController.dispose();
    super.dispose();
  }

  Future<void> _submitVehicle() async {
    if (!_formKey.currentState!.validate() || _selectedType == null) return;

    setState(() => _isSubmitting = true);

    final response = widget.initialData == null
        ? await VehicleApiService.addVehicle(
            vehicleType: _selectedType!,
            vehicleNumber: _registrationController.text.trim().toUpperCase(),
          )
        : await VehicleApiService.updateVehicle(
            vehicleId: widget.initialData!['vehicle_id'].toString(),
            vehicleType: _selectedType,
            vehicleNumber: _registrationController.text.trim().toUpperCase(),
          );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.error ?? 'Unable to save vehicle.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.initialData == null
              ? 'Vehicle added successfully.'
              : 'Vehicle updated successfully.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialData == null ? 'Add Vehicle' : 'Edit Vehicle',
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicle Type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: _inputDecoration(Icons.category),
                items: _vehicleTypes
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type['value'],
                        child: Text(type['label']!),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value),
                validator: (value) =>
                    value == null ? 'Please select a vehicle type' : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Registration Number'),
              TextFormField(
                controller: _registrationController,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(Icons.pin),
                validator: (value) {
                  final normalized = (value ?? '').trim().toUpperCase();
                  if (normalized.isEmpty) {
                    return 'Enter your registration number';
                  }
                  if (!_indianPlateRegExp.hasMatch(normalized)) {
                    return 'Enter a valid registration number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                'This form is aligned to the current backend vehicle schema: type and registration number.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitVehicle,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.initialData == null
                              ? 'Save Vehicle'
                              : 'Update Vehicle',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

InputDecoration _inputDecoration(IconData icon) => InputDecoration(
  prefixIcon: Icon(icon, color: Colors.green),
  filled: true,
  fillColor: Colors.grey.shade50,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade200),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Colors.green),
  ),
);

String _displayValue(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? 'Not set' : text;
}

String _formatGender(String? value) {
  switch (value) {
    case 'male':
      return 'Male';
    case 'female':
      return 'Female';
    case 'other':
      return 'Other';
    default:
      return 'Not set';
  }
}

String _vehicleTypeLabel(String? value) {
  switch (value) {
    case '2_wheeler':
      return 'Two Wheeler';
    case '4_wheeler':
      return 'Four Wheeler';
    default:
      return 'Vehicle';
  }
}
