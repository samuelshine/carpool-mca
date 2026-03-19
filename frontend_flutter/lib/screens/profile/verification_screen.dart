import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../services/demo_mode_service.dart';

class VerificationScreen extends StatefulWidget {
  final bool demoMode;

  const VerificationScreen({super.key, this.demoMode = false});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profile;
  Map<String, dynamic> _identityStatus = const {'status': 'not_submitted'};
  Map<String, dynamic> _driverStatus = const {'status': 'not_submitted'};

  @override
  void initState() {
    super.initState();
    _loadVerificationState();
  }

  Future<void> _loadVerificationState() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.demoMode) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _profile = DemoModeData.demoProfile();
        _identityStatus = DemoModeData.demoIdentityStatus();
        _driverStatus = DemoModeData.demoDriverVerificationStatus();
      });
      return;
    }

    final profileRes = await UserApiService.getMyProfile();
    final identityRes = await VerificationApiService.getIdentityStatus();
    final driverRes =
        await VerificationApiService.getDriverVerificationStatus();

    if (!mounted) return;

    if (!profileRes.success || profileRes.data is! Map<String, dynamic>) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            profileRes.error ?? 'Unable to load your verification state.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _profile = profileRes.data as Map<String, dynamic>;
      _identityStatus = identityRes.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(identityRes.data as Map<String, dynamic>)
          : const {'status': 'not_submitted'};
      _driverStatus = driverRes.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(driverRes.data as Map<String, dynamic>)
          : const {'status': 'not_submitted'};
    });
  }

  bool get _isEmailVerified => _profile?['is_email_verified'] == true;
  bool get _isIdentityVerified => _profile?['is_identity_verified'] == true;
  bool get _isDriverVerified => _profile?['is_driver_verified'] == true;

  void _showDemoNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Demo Mode shows approved verification states without submitting live documents.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verification Center',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadVerificationState,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.demoMode) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Text(
                        'These verification states are seeded for demos so you can explain the onboarding and approval journey safely.',
                        style: TextStyle(color: Colors.black54, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildOverviewCard(),
                  const SizedBox(height: 16),
                  _buildStatusCard(
                    title: 'College Email and Identity',
                    subtitle:
                        'Verify your Christ University email and submit your college ID for review.',
                    icon: Icons.school_outlined,
                    color: Colors.orange,
                    statusLabel: _combinedStudentStatusLabel(),
                    onTap: widget.demoMode
                        ? _showDemoNote
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CollegeVerificationScreen(
                                  initialEmail: _profile?['email']?.toString(),
                                  isEmailVerified: _isEmailVerified,
                                  identityVerified: _isIdentityVerified,
                                  initialIdentityStatus: _identityStatus,
                                ),
                              ),
                            );
                            _loadVerificationState();
                          },
                  ),
                  const SizedBox(height: 12),
                  _buildStatusCard(
                    title: 'Driver Licence Verification',
                    subtitle:
                        'Required before you can add backend vehicles or create rides.',
                    icon: Icons.badge_outlined,
                    color: Colors.blue,
                    statusLabel: _statusLabel(
                      _driverStatus['status']?.toString(),
                    ),
                    onTap: widget.demoMode
                        ? _showDemoNote
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LicenseVerificationScreen(
                                  identityVerified: _isIdentityVerified,
                                  driverVerified: _isDriverVerified,
                                  initialDriverStatus: _driverStatus,
                                ),
                              ),
                            );
                            _loadVerificationState();
                          },
                  ),
                  const SizedBox(height: 16),
                  _buildUnlocksCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verification Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _VerificationChip(
                label: _isEmailVerified
                    ? 'Email verified'
                    : 'Email not verified',
                color: _isEmailVerified ? Colors.green : Colors.orange,
              ),
              _VerificationChip(
                label: _isIdentityVerified
                    ? 'Identity verified'
                    : 'Identity not verified',
                color: _isIdentityVerified ? Colors.green : Colors.orange,
              ),
              _VerificationChip(
                label: _isDriverVerified
                    ? 'Driver verified'
                    : 'Driver not verified',
                color: _isDriverVerified ? Colors.green : Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Only college-email-verified users can book rides. Only driver-verified users can add backend vehicles and offer rides.',
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String statusLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  _VerificationChip(label: statusLabel, color: color),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlocksCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Access Rules',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _buildRuleRow(
            isUnlocked: _isEmailVerified,
            label: 'Book rides and send join requests',
          ),
          _buildRuleRow(
            isUnlocked: _isIdentityVerified,
            label: 'Submit driver verification',
          ),
          _buildRuleRow(
            isUnlocked: _isDriverVerified,
            label: 'Add backend vehicles and create rides',
          ),
          _buildRuleRow(
            isUnlocked: false,
            label: 'Vehicle verification for ride creation',
            trailing: 'Pending backend support',
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow({
    required bool isUnlocked,
    required String label,
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            isUnlocked ? Icons.check_circle : Icons.lock_outline,
            size: 18,
            color: isUnlocked ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load verification details.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _loadVerificationState,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  String _combinedStudentStatusLabel() {
    if (_isIdentityVerified) return 'Identity verified';
    if (_isEmailVerified) return 'Email verified, ID review pending';
    return 'Not verified';
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'submitted':
        return 'Pending review';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Not submitted';
    }
  }
}

class CollegeVerificationScreen extends StatefulWidget {
  final String? initialEmail;
  final bool isEmailVerified;
  final bool identityVerified;
  final Map<String, dynamic> initialIdentityStatus;

  const CollegeVerificationScreen({
    super.key,
    required this.initialEmail,
    required this.isEmailVerified,
    required this.identityVerified,
    required this.initialIdentityStatus,
  });

  @override
  State<CollegeVerificationScreen> createState() =>
      _CollegeVerificationScreenState();
}

class _CollegeVerificationScreenState extends State<CollegeVerificationScreen> {
  static final RegExp _christEmailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9-]+\.)*christuniversity\.in$',
    caseSensitive: false,
  );

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _collegeIdController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _identityImage;
  bool _isEmailVerified = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isSubmittingIdentity = false;
  bool _showOtpField = false;
  String? _emailSessionToken;
  Map<String, dynamic> _identityStatus = const {'status': 'not_submitted'};

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
    _isEmailVerified = widget.isEmailVerified;
    _identityStatus = Map<String, dynamic>.from(widget.initialIdentityStatus);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _collegeIdController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_isValidChristEmail(_emailController.text.trim())) {
      _showMessage(
        'Use your Christ University email in the format *@*.christuniversity.in.',
        isError: true,
      );
      return;
    }

    setState(() => _isSendingOtp = true);
    final res = await VerificationApiService.sendEmailOtp(
      _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSendingOtp = false);

    if (!res.success || res.data is! Map<String, dynamic>) {
      _showMessage(res.error ?? 'Unable to send OTP right now.', isError: true);
      return;
    }

    final data = res.data as Map<String, dynamic>;
    setState(() {
      _emailSessionToken = data['email_session_token']?.toString();
      _showOtpField = _emailSessionToken != null;
    });
    _showMessage(data['message']?.toString() ?? 'OTP sent successfully.');
  }

  Future<void> _verifyOtp() async {
    final sessionToken = _emailSessionToken;
    if (sessionToken == null) {
      _showMessage('Send OTP first.', isError: true);
      return;
    }
    if (_otpController.text.trim().length != 6) {
      _showMessage('Enter the 6-digit OTP.', isError: true);
      return;
    }

    setState(() => _isVerifyingOtp = true);
    final res = await VerificationApiService.verifyEmailOtp(
      sessionToken,
      _otpController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isVerifyingOtp = false);

    if (!res.success) {
      _showMessage(res.error ?? 'OTP verification failed.', isError: true);
      return;
    }

    setState(() {
      _isEmailVerified = true;
      _showOtpField = false;
      _emailSessionToken = null;
    });
    _showMessage('College email verified successfully.');
  }

  Future<void> _pickIdentityImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _identityImage = File(image.path));
    }
  }

  Future<void> _submitIdentity() async {
    if (!_isEmailVerified) {
      _showMessage(
        'Verify your college email before submitting identity documents.',
        isError: true,
      );
      return;
    }
    if (_identityImage == null) {
      _showMessage('Upload your college ID image first.', isError: true);
      return;
    }

    setState(() => _isSubmittingIdentity = true);
    final res = await VerificationApiService.submitIdentityVerification(
      documentUrl: await _fileToDataUrl(_identityImage!),
      collegeIdNumber: _collegeIdController.text.trim().isEmpty
          ? null
          : _collegeIdController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmittingIdentity = false);

    if (!res.success) {
      _showMessage(
        res.error ?? 'Unable to submit identity verification.',
        isError: true,
      );
      return;
    }

    await _refreshIdentityStatus();
    _showMessage(
      res.data is Map<String, dynamic>
          ? (res.data as Map<String, dynamic>)['message']?.toString() ??
                'Identity verification submitted.'
          : 'Identity verification submitted.',
    );
  }

  Future<void> _refreshIdentityStatus() async {
    final res = await VerificationApiService.getIdentityStatus();
    if (!mounted || !res.success || res.data is! Map<String, dynamic>) return;
    setState(() {
      _identityStatus = Map<String, dynamic>.from(
        res.data as Map<String, dynamic>,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final identityStatus =
        _identityStatus['status']?.toString() ?? 'not_submitted';
    final canSubmitIdentity =
        _isEmailVerified &&
        (identityStatus == 'not_submitted' || identityStatus == 'rejected');

    return Scaffold(
      appBar: AppBar(title: const Text('College Verification')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusSummaryCard(
            title: 'Student verification',
            chips: [
              _StatusChipData(
                label: _isEmailVerified
                    ? 'Email verified'
                    : 'Email not verified',
                color: _isEmailVerified ? Colors.green : Colors.orange,
              ),
              _StatusChipData(
                label: _statusLabel(identityStatus),
                color: _statusColor(identityStatus),
              ),
            ],
            description:
                'Step 1 verifies your Christ University email. Step 2 submits your college ID for admin review.',
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Step 1: Verify college email',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(
                    'College email',
                    icon: Icons.email_outlined,
                  ),
                  enabled: !_isEmailVerified,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Accepted format: *@*.christuniversity.in',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_showOtpField) ...[
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: _inputDecoration(
                      'Enter OTP',
                      icon: Icons.lock_outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isVerifyingOtp ? null : _verifyOtp,
                    icon: _isVerifyingOtp
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_outlined),
                    label: const Text('Verify OTP'),
                  ),
                ] else
                  ElevatedButton.icon(
                    onPressed: _isEmailVerified || _isSendingOtp
                        ? null
                        : _sendOtp,
                    icon: _isSendingOtp
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _isEmailVerified ? 'Email already verified' : 'Send OTP',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Step 2: Submit college ID',
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _collegeIdController,
                    decoration: _inputDecoration(
                      'College ID number (optional)',
                      icon: Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ImagePickerBox(
                    imageFile: _identityImage,
                    onTap: canSubmitIdentity ? _pickIdentityImage : null,
                    hint: 'Upload college ID image',
                  ),
                  if (_identityStatus['reviewer_notes'] != null) ...[
                    const SizedBox(height: 12),
                    _ReviewerNotesBox(
                      notes: _identityStatus['reviewer_notes'].toString(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: canSubmitIdentity && !_isSubmittingIdentity
                        ? _submitIdentity
                        : null,
                    icon: _isSubmittingIdentity
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(switch (identityStatus) {
                      'verified' => 'Identity already verified',
                      'submitted' => 'Identity review pending',
                      'rejected' => 'Resubmit identity',
                      _ => 'Submit identity for review',
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isValidChristEmail(String email) {
    return _christEmailPattern.hasMatch(email.trim());
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
}

class LicenseVerificationScreen extends StatefulWidget {
  final bool identityVerified;
  final bool driverVerified;
  final Map<String, dynamic> initialDriverStatus;

  const LicenseVerificationScreen({
    super.key,
    required this.identityVerified,
    required this.driverVerified,
    required this.initialDriverStatus,
  });

  @override
  State<LicenseVerificationScreen> createState() =>
      _LicenseVerificationScreenState();
}

class _LicenseVerificationScreenState extends State<LicenseVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _licenseNoController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _licenseImage;
  bool _isSubmitting = false;
  Map<String, dynamic> _driverStatus = const {'status': 'not_submitted'};

  @override
  void initState() {
    super.initState();
    _driverStatus = Map<String, dynamic>.from(widget.initialDriverStatus);
  }

  @override
  void dispose() {
    _licenseNoController.dispose();
    super.dispose();
  }

  Future<void> _pickLicenseImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() => _licenseImage = File(image.path));
    }
  }

  Future<void> _submitDriverVerification() async {
    if (!widget.identityVerified) {
      _showMessage(
        'Identity verification must be approved before driver verification.',
        isError: true,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_licenseImage == null) {
      _showMessage('Capture your licence image first.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await VerificationApiService.submitDriverVerification(
      licenseDocumentUrl: await _fileToDataUrl(_licenseImage!),
      licenseNumber: _licenseNoController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!res.success) {
      _showMessage(
        res.error ?? 'Unable to submit driver verification.',
        isError: true,
      );
      return;
    }

    await _refreshDriverStatus();
    _showMessage(
      res.data is Map<String, dynamic>
          ? (res.data as Map<String, dynamic>)['message']?.toString() ??
                'Driver verification submitted.'
          : 'Driver verification submitted.',
    );
  }

  Future<void> _refreshDriverStatus() async {
    final res = await VerificationApiService.getDriverVerificationStatus();
    if (!mounted || !res.success || res.data is! Map<String, dynamic>) return;
    setState(() {
      _driverStatus = Map<String, dynamic>.from(
        res.data as Map<String, dynamic>,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _driverStatus['status']?.toString() ?? 'not_submitted';
    final canSubmit =
        widget.identityVerified &&
        (status == 'not_submitted' || status == 'rejected');

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Verification')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusSummaryCard(
            title: 'Driver status',
            chips: [
              _StatusChipData(
                label: widget.identityVerified
                    ? 'Identity approved'
                    : 'Identity approval required',
                color: widget.identityVerified ? Colors.green : Colors.orange,
              ),
              _StatusChipData(
                label: _statusLabel(status),
                color: _statusColor(status),
              ),
            ],
            description:
                'Driver verification unlocks backend vehicle addition and ride creation.',
          ),
          if (!widget.identityVerified) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'Finish college email and identity verification first. Driver verification is locked until identity is approved.',
                style: TextStyle(color: Colors.black87, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Driving licence submission',
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _licenseNoController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _inputDecoration(
                      'Licence number',
                      icon: Icons.credit_card_outlined,
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Please enter your licence number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _ImagePickerBox(
                    imageFile: _licenseImage,
                    onTap: canSubmit ? _pickLicenseImage : null,
                    hint: 'Capture licence image',
                  ),
                  if (_driverStatus['reviewer_notes'] != null) ...[
                    const SizedBox(height: 12),
                    _ReviewerNotesBox(
                      notes: _driverStatus['reviewer_notes'].toString(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: canSubmit && !_isSubmitting
                        ? _submitDriverVerification
                        : null,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_user_outlined),
                    label: Text(switch (status) {
                      'verified' => 'Driver already verified',
                      'submitted' => 'Driver review pending',
                      'rejected' => 'Resubmit licence',
                      _ => 'Submit licence for review',
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
}

class _StatusSummaryCard extends StatelessWidget {
  final String title;
  final List<_StatusChipData> chips;
  final String description;

  const _StatusSummaryCard({
    required this.title,
    required this.chips,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (chip) =>
                      _VerificationChip(label: chip.label, color: chip.color),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _VerificationChip extends StatelessWidget {
  final String label;
  final Color color;

  const _VerificationChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatusChipData {
  final String label;
  final Color color;

  const _StatusChipData({required this.label, required this.color});
}

class _ImagePickerBox extends StatelessWidget {
  final File? imageFile;
  final VoidCallback? onTap;
  final String hint;

  const _ImagePickerBox({
    required this.imageFile,
    required this.onTap,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 190,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: imageFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(hint, style: TextStyle(color: Colors.grey.shade600)),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(imageFile!, fit: BoxFit.cover),
              ),
      ),
    );
  }
}

class _ReviewerNotesBox extends StatelessWidget {
  final String notes;

  const _ReviewerNotesBox({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviewer notes',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange),
          ),
          const SizedBox(height: 4),
          Text(notes),
        ],
      ),
    );
  }
}

Widget _buildSectionCard({required String title, required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

InputDecoration _inputDecoration(String hint, {required IconData icon}) {
  return InputDecoration(
    hintText: hint,
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
}

String _statusLabel(String status) {
  switch (status) {
    case 'verified':
      return 'Verified';
    case 'submitted':
      return 'Pending review';
    case 'rejected':
      return 'Rejected';
    default:
      return 'Not submitted';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'verified':
      return Colors.green;
    case 'submitted':
      return Colors.blue;
    case 'rejected':
      return Colors.red;
    default:
      return Colors.orange;
  }
}

Future<String> _fileToDataUrl(File file) async {
  final bytes = await file.readAsBytes();
  final encoded = base64Encode(bytes);
  final path = file.path.toLowerCase();
  final mimeType = path.endsWith('.png') ? 'image/png' : 'image/jpeg';
  return 'data:$mimeType;base64,$encoded';
}
