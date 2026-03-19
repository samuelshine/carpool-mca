import 'package:flutter/material.dart';

import '../auth/common_widgets.dart';
import '../../services/api_service.dart';
import '../../services/demo_mode_service.dart';
import '../../services/location_service.dart';

class SafetyCenterScreen extends StatefulWidget {
  final bool demoMode;

  const SafetyCenterScreen({super.key, this.demoMode = false});

  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _busyRideId;
  String? _deletingContactId;
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _sosAlerts = [];
  List<Map<String, dynamic>> _rideHistory = [];
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadSafetyData();
  }

  Future<void> _loadSafetyData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.demoMode) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _contacts = DemoModeData.demoEmergencyContacts();
        _sosAlerts = DemoModeData.demoSosAlerts();
        _rideHistory = DemoModeData.demoRideHistory();
        _reports = DemoModeData.demoReports();
      });
      return;
    }

    final contactsRes = await EmergencyContactApiService.listContacts();
    final sosRes = await SOSApiService.getActive();
    final historyRes = await RideApiService.listRideHistory();
    final reportsRes = await ReportApiService.getMyReports();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _errorMessage = [
        contactsRes.error,
        sosRes.error,
        historyRes.error,
        reportsRes.error,
      ].whereType<String>().firstOrNull;
      _contacts = _asMapList(contactsRes.data);
      _sosAlerts = _asMapList(sosRes.data);
      _rideHistory = _asMapList(historyRes.data);
      _reports = _asMapList(reportsRes.data);
    });
  }

  List<Map<String, dynamic>> get _activeRides {
    return _rideHistory
        .where((ride) => ride['history_state'] == 'active')
        .toList();
  }

  Future<void> _triggerSos(Map<String, dynamic> ride) async {
    final rideId = ride['ride_id']?.toString();
    if (rideId == null) return;

    if (widget.demoMode) {
      setState(() {
        _sosAlerts = [
          {
            'alert_id': 'demo-sos-${DateTime.now().millisecondsSinceEpoch}',
            'ride_id': rideId,
            'triggered_at': DateTime.now().toUtc().toIso8601String(),
          },
          ..._sosAlerts,
        ];
      });
      _showMessage(
        'Demo SOS recorded locally. Use this to explain what would happen in a real emergency.',
      );
      return;
    }

    setState(() => _busyRideId = rideId);

    try {
      final location = await LocationService.getCurrentLocation();
      final res = await SOSApiService.trigger(
        rideId: rideId,
        latitude: location.latitude,
        longitude: location.longitude,
      );

      if (!mounted) return;
      setState(() => _busyRideId = null);

      if (!res.success) {
        _showMessage(
          res.error ?? 'Unable to send the SOS alert right now.',
          isError: true,
        );
        return;
      }

      _showMessage(
        'SOS alert sent with your current location. Check your emergency contacts below.',
      );
      await _loadSafetyData();
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() => _busyRideId = null);
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyRideId = null);
      _showMessage(
        'Unable to access your location for SOS right now.',
        isError: true,
      );
    }
  }

  Future<void> _showContactSheet() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Emergency Contact',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: nameController,
                    label: 'Contact name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: phoneController,
                    label: 'Phone number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: relationshipController,
                    label: 'Relationship',
                    icon: Icons.favorite_outline,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim();
                              final relationship = relationshipController.text
                                  .trim();

                              if (name.isEmpty ||
                                  phone.isEmpty ||
                                  relationship.isEmpty) {
                                _showMessage(
                                  'Fill in name, phone number, and relationship.',
                                  isError: true,
                                );
                                return;
                              }

                              if (widget.demoMode) {
                                setState(() {
                                  _contacts = [
                                    {
                                      'contact_id':
                                          'demo-contact-${DateTime.now().millisecondsSinceEpoch}',
                                      'contact_name': name,
                                      'contact_phone': phone,
                                      'relationship': relationship,
                                    },
                                    ..._contacts,
                                  ];
                                });
                                if (!mounted) return;
                                Navigator.pop(context);
                                _showMessage(
                                  'Demo emergency contact saved locally.',
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);
                              final res =
                                  await EmergencyContactApiService.addContact(
                                    contactName: name,
                                    contactPhone: phone,
                                    relationship: relationship,
                                  );
                              if (!mounted) return;
                              setModalState(() => isSubmitting = false);

                              if (!res.success) {
                                _showMessage(
                                  res.error ??
                                      'Unable to save emergency contact.',
                                  isError: true,
                                );
                                return;
                              }

                              Navigator.pop(context);
                              _showMessage('Emergency contact saved.');
                              await _loadSafetyData();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Contact',
                              style: TextStyle(color: Colors.white),
                            ),
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

  Future<void> _deleteContact(Map<String, dynamic> contact) async {
    final contactId = contact['contact_id']?.toString();
    if (contactId == null) return;

    if (widget.demoMode) {
      setState(() {
        _contacts = _contacts
            .where((item) => item['contact_id']?.toString() != contactId)
            .toList();
      });
      _showMessage('Demo emergency contact removed.');
      return;
    }

    setState(() => _deletingContactId = contactId);
    final res = await EmergencyContactApiService.deleteContact(contactId);
    if (!mounted) return;
    setState(() => _deletingContactId = null);

    if (!res.success) {
      _showMessage(
        res.error ?? 'Unable to remove emergency contact.',
        isError: true,
      );
      return;
    }

    _showMessage('Emergency contact removed.');
    await _loadSafetyData();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : kPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Safety Center',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _contacts.isEmpty && _sosAlerts.isEmpty
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadSafetyData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildIntroCard(cardColor),
                  const SizedBox(height: 16),
                  _buildEmergencyActionsCard(cardColor),
                  const SizedBox(height: 16),
                  _buildEmergencyContactsCard(cardColor),
                  const SizedBox(height: 16),
                  _buildSosHistoryCard(cardColor),
                  const SizedBox(height: 16),
                  _buildReportsSummaryCard(cardColor),
                ],
              ),
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
            const Icon(Icons.error_outline, size: 42, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load safety tools right now.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadSafetyData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Emergency readiness',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'Use this space to manage emergency contacts, send SOS alerts for active rides, and review any reports or past alerts tied to your account.',
            style: TextStyle(color: kMuted, height: 1.4),
          ),
          if (widget.demoMode) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'Demo Mode keeps SOS alerts, contacts, and reports local to the presentation flow.',
                style: TextStyle(color: kMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmergencyActionsCard(Color cardColor) {
    return _buildSectionCard(
      title: 'Emergency Actions',
      cardColor: cardColor,
      trailing: Text(
        '${_activeRides.length} active',
        style: const TextStyle(color: kMuted, fontSize: 12),
      ),
      child: _activeRides.isEmpty
          ? const Text(
              'No active rides right now. SOS is also available directly from the live ride screen.',
              style: TextStyle(color: kMuted, height: 1.4),
            )
          : Column(
              children: _activeRides.map((ride) {
                final rideId = ride['ride_id']?.toString();
                final isBusy = _busyRideId == rideId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kCardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ride['start_address'] ?? 'Pickup'} -> ${ride['end_address'] ?? 'Destination'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_roleLabel(ride['user_role']?.toString())} • ${ride['status_label'] ?? 'ACTIVE'}',
                        style: const TextStyle(color: kMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isBusy ? null : () => _triggerSos(ride),
                          icon: isBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sos, color: Colors.white),
                          label: const Text(
                            'Send SOS For This Ride',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildEmergencyContactsCard(Color cardColor) {
    return _buildSectionCard(
      title: 'Emergency Contacts',
      cardColor: cardColor,
      trailing: TextButton.icon(
        onPressed: () => _showContactSheet(),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add'),
      ),
      child: _contacts.isEmpty
          ? const Text(
              'No emergency contacts saved yet. Add at least one contact so they are ready when you need them.',
              style: TextStyle(color: kMuted, height: 1.4),
            )
          : Column(
              children: _contacts.map((contact) {
                final contactId = contact['contact_id']?.toString();
                final isDeleting = _deletingContactId == contactId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: kPrimary.withValues(alpha: 0.12),
                    child: const Icon(Icons.phone, color: kPrimary),
                  ),
                  title: Text(contact['contact_name']?.toString() ?? 'Contact'),
                  subtitle: Text(
                    '${contact['relationship'] ?? 'Emergency contact'} • ${contact['contact_phone'] ?? ''}',
                  ),
                  trailing: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: () => _deleteContact(contact),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSosHistoryCard(Color cardColor) {
    return _buildSectionCard(
      title: 'SOS History',
      cardColor: cardColor,
      child: _sosAlerts.isEmpty
          ? const Text(
              'No SOS alerts have been triggered from this account yet.',
              style: TextStyle(color: kMuted, height: 1.4),
            )
          : Column(
              children: _sosAlerts.map((alert) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withValues(alpha: 0.12),
                    child: const Icon(Icons.warning_amber, color: Colors.red),
                  ),
                  title: Text('Ride ${_shortId(alert['ride_id'])}'),
                  subtitle: Text(
                    'Triggered ${_formatDateTime(alert['triggered_at']?.toString())}',
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildReportsSummaryCard(Color cardColor) {
    return _buildSectionCard(
      title: 'Reporting',
      cardColor: cardColor,
      trailing: TextButton.icon(
        onPressed: () =>
            widget.demoMode ? _showDemoReportSheet() : _openReportFlow(),
        icon: const Icon(Icons.flag_outlined, size: 18),
        label: const Text('New Report'),
      ),
      child: _reports.isEmpty
          ? const Text(
              'No reports submitted yet. Use reporting when you need to flag unsafe or inappropriate ride behavior.',
              style: TextStyle(color: kMuted, height: 1.4),
            )
          : Column(
              children: _reports.take(5).map((report) {
                final relatedRide = _rideHistory
                    .where(
                      (ride) =>
                          ride['ride_id']?.toString() ==
                          report['ride_id']?.toString(),
                    )
                    .firstOrNull;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.12),
                    child: const Icon(Icons.flag, color: Colors.orange),
                  ),
                  title: Text(
                    relatedRide != null
                        ? '${relatedRide['start_address']} -> ${relatedRide['end_address']}'
                        : 'Ride ${_shortId(report['ride_id'])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_formatDateTime(report['created_at']?.toString())}\n${report['comment'] ?? ''}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Color cardColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Future<void> _openReportFlow() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ReportUserScreen()),
    );
    if (created == true) {
      await _loadSafetyData();
    }
  }

  Future<void> _showDemoReportSheet() async {
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Demo Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe the issue you want to present in the demo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  setState(() {
                    _reports = [
                      {
                        'report_id':
                            'demo-report-${DateTime.now().millisecondsSinceEpoch}',
                        'ride_id': DemoModeData.liveRideId,
                        'comment': text,
                        'created_at': DateTime.now().toUtc().toIso8601String(),
                      },
                      ..._reports,
                    ];
                  });
                  Navigator.pop(context);
                  _showMessage('Demo report added locally.');
                },
                style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
                child: const Text(
                  'Save Demo Report',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportUserScreen extends StatefulWidget {
  const ReportUserScreen({super.key});

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  final _commentController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLoadingTargets = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _rideHistory = [];
  List<Map<String, dynamic>> _targetUsers = [];
  Map<String, dynamic>? _selectedRide;
  Map<String, dynamic>? _selectedTarget;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final res = await RideApiService.listRideHistory();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = res.success ? null : res.error;
      _rideHistory = _asMapList(
        res.data,
      ).where((ride) => ride['history_state'] != 'requested').toList();
    });
  }

  Future<void> _loadTargetsForRide(Map<String, dynamic>? ride) async {
    setState(() {
      _selectedRide = ride;
      _selectedTarget = null;
      _targetUsers = [];
      _isLoadingTargets = ride != null;
    });

    if (ride == null) return;

    final userRole = ride['user_role']?.toString();

    if (userRole == 'driver') {
      final res = await RideApiService.getRideParticipants(
        ride['ride_id'].toString(),
      );
      if (!mounted) return;

      final participants = _asMapList(res.data)
          .map(
            (item) => {
              'user_id': item['user_id']?.toString(),
              'label': item['full_name']?.toString() ?? 'Passenger',
              'subtitle': item['phone_number']?.toString() ?? '',
            },
          )
          .where((item) => item['user_id'] != null)
          .toList();

      setState(() {
        _isLoadingTargets = false;
        _targetUsers = participants;
      });
      return;
    }

    final driverId = ride['driver_id']?.toString();
    if (driverId != null) {
      setState(() {
        _isLoadingTargets = false;
        _targetUsers = [
          {
            'user_id': driverId,
            'label': ride['driver_name']?.toString() ?? 'Driver',
            'subtitle': 'Driver for this ride',
          },
        ];
        _selectedTarget = {
          'user_id': driverId,
          'label': ride['driver_name']?.toString() ?? 'Driver',
          'subtitle': 'Driver for this ride',
        };
      });
      return;
    }

    setState(() => _isLoadingTargets = false);
  }

  Future<void> _submitReport() async {
    final rideId = _selectedRide?['ride_id']?.toString();
    final reportedUserId = _selectedTarget?['user_id']?.toString();
    final comment = _commentController.text.trim();

    if (rideId == null || reportedUserId == null) {
      _showMessage(
        'Choose a ride and the person you want to report.',
        isError: true,
      );
      return;
    }
    if (comment.length < 10) {
      _showMessage(
        'Please describe the issue in at least 10 characters.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await ReportApiService.submitReport(
      rideId: rideId,
      reportedUserId: reportedUserId,
      comment: comment,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!res.success) {
      _showMessage(res.error ?? 'Unable to submit report.', isError: true);
      return;
    }

    _showMessage('Report submitted successfully.');
    Navigator.pop(context, true);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : kPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Report User or Driver',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.orange,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadHistory,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kCardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose the ride, then choose the driver or passenger involved. Reports are tied to a ride so the moderation trail stays clear.',
                        style: TextStyle(color: kMuted, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRide?['ride_id']?.toString(),
                        decoration: _inputDecoration(
                          'Select ride',
                          icon: Icons.route_outlined,
                        ),
                        items: _rideHistory
                            .map(
                              (ride) => DropdownMenuItem<String>(
                                value: ride['ride_id']?.toString(),
                                child: Text(
                                  '${ride['start_address']} -> ${ride['end_address']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          final ride = _rideHistory
                              .where(
                                (item) => item['ride_id']?.toString() == value,
                              )
                              .firstOrNull;
                          _loadTargetsForRide(ride);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_selectedRide != null)
                        Text(
                          '${_roleLabel(_selectedRide!['user_role']?.toString())} • ${_selectedRide!['status_label'] ?? ''}',
                          style: const TextStyle(color: kMuted, fontSize: 12),
                        ),
                      const SizedBox(height: 12),
                      if (_isLoadingTargets)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_selectedRide == null)
                        const Text(
                          'Select a ride first to choose who to report.',
                          style: TextStyle(color: kMuted),
                        )
                      else if (_selectedRide != null && _targetUsers.isEmpty)
                        const Text(
                          'No reportable counterparties found for this ride yet.',
                          style: TextStyle(color: Colors.orange),
                        )
                      else if (_targetUsers.length == 1 &&
                          _selectedTarget != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, color: kPrimary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_selectedTarget!['label']} • ${_selectedTarget!['subtitle']}',
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedTarget?['user_id']?.toString(),
                          decoration: _inputDecoration(
                            'Select user',
                            icon: Icons.person_outline,
                          ),
                          items: _targetUsers
                              .map(
                                (target) => DropdownMenuItem<String>(
                                  value: target['user_id']?.toString(),
                                  child: Text(
                                    target['label']?.toString() ?? 'User',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTarget = _targetUsers
                                  .where(
                                    (item) =>
                                        item['user_id']?.toString() == value,
                                  )
                                  .firstOrNull;
                            });
                          },
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _commentController,
                        minLines: 4,
                        maxLines: 6,
                        decoration: _inputDecoration(
                          'Describe what happened',
                          icon: Icons.feedback_outlined,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitReport,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.flag, color: Colors.white),
                          label: const Text(
                            'Submit Report',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

InputDecoration _inputDecoration(String label, {required IconData icon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: kPrimary),
    filled: true,
    fillColor: kBackground,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: kCardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: kCardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimary),
    ),
  );
}

Widget _buildInputField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: _inputDecoration(label, icon: icon),
  );
}

String _formatDateTime(String? value) {
  if (value == null || value.isEmpty) return 'recently';
  return value.replaceFirst('T', ' ').split('.').first;
}

String _shortId(Object? value) {
  final text = value?.toString() ?? '';
  if (text.length <= 8) return text;
  return text.substring(0, 8);
}

String _roleLabel(String? role) {
  switch (role) {
    case 'driver':
      return 'Driver';
    case 'passenger':
      return 'Passenger';
    case 'requester':
      return 'Request';
    default:
      return 'Ride';
  }
}

List<Map<String, dynamic>> _asMapList(dynamic data) {
  if (data is! List) return [];
  return data
      .whereType<Map>()
      .map<Map<String, dynamic>>(
        (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
      )
      .toList();
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
