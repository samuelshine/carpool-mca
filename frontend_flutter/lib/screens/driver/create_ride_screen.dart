import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../auth/common_widgets.dart';
import '../home/pin_drop_screen.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  static const List<Map<String, dynamic>> _campuses = [
    {
      'name': 'Christ University - Central Campus',
      'address': 'Hosur Road, Bangalore',
      'lat': 12.9347,
      'lng': 77.6066,
    },
    {
      'name': 'Christ University - Kengeri Campus',
      'address': 'Kengeri, Bangalore',
      'lat': 12.9137,
      'lng': 77.4829,
    },
    {
      'name': 'Christ University - Yeshwantpur Campus',
      'address': 'Yeshwantpur, Bangalore',
      'lat': 13.0230,
      'lng': 77.5440,
    },
    {
      'name': 'Christ University - Bannerghatta Campus',
      'address': 'Bannerghatta Road, Bangalore',
      'lat': 12.8698,
      'lng': 77.5950,
    },
  ];

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _communityController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isResolvingPickup = false;
  bool _isDriverVerified = false;
  String? _loadError;
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedVehicleId;
  String? _selectedCampusName;
  LatLng? _pickupLatLng;
  DateTime _rideDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _rideTime = _nextTimeSlot();
  int _availableSeats = 1;
  int _seatLimit = 4;
  String _allowedGender = 'any';
  double? _estimatedFare;

  static TimeOfDay _nextTimeSlot() {
    final now = DateTime.now().add(const Duration(minutes: 30));
    final roundedMinute = now.minute < 30 ? 30 : 0;
    final hour = now.minute < 30 ? now.hour : (now.hour + 1) % 24;
    return TimeOfDay(hour: hour, minute: roundedMinute);
  }

  @override
  void initState() {
    super.initState();
    _loadSetupData();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _communityController.dispose();
    super.dispose();
  }

  Future<void> _loadSetupData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final userRes = await UserApiService.getMyProfile();
    final vehiclesRes = await VehicleApiService.getMyVehicles();
    final profileRes = await DriverProfileApiService.getMyDriverProfile();

    if (!mounted) return;

    if (!userRes.success || userRes.data is! Map<String, dynamic>) {
      setState(() {
        _isLoading = false;
        _loadError = userRes.error ?? 'Unable to load your profile.';
      });
      return;
    }

    _isDriverVerified =
        (userRes.data as Map<String, dynamic>)['is_driver_verified'] == true;

    if (!_isDriverVerified) {
      setState(() {
        _isLoading = false;
        _loadError =
            'Driver verification is required before you can add backend vehicles or create rides.';
      });
      return;
    }

    if (!vehiclesRes.success) {
      setState(() {
        _isLoading = false;
        _loadError = vehiclesRes.error ?? 'Unable to load your vehicles.';
      });
      return;
    }

    final vehicles = <Map<String, dynamic>>[];
    if (vehiclesRes.data is List) {
      for (final item in vehiclesRes.data as List) {
        if (item is Map<String, dynamic>) {
          vehicles.add(item);
        }
      }
    }

    String? selectedVehicleId;
    int seatLimit = 4;

    if (profileRes.success && profileRes.data is Map<String, dynamic>) {
      final profile = profileRes.data as Map<String, dynamic>;
      selectedVehicleId = profile['vehicle_id']?.toString();
      seatLimit = (profile['daily_seat_limit'] as num?)?.toInt() ?? seatLimit;
    }

    if (selectedVehicleId == null && vehicles.isNotEmpty) {
      selectedVehicleId = vehicles.first['vehicle_id']?.toString();
    }

    final knownVehicleIds = vehicles
        .map((vehicle) => vehicle['vehicle_id']?.toString())
        .whereType<String>()
        .toSet();
    if (selectedVehicleId != null && !knownVehicleIds.contains(selectedVehicleId)) {
      selectedVehicleId = vehicles.first['vehicle_id']?.toString();
    }

    if (vehicles.isEmpty) {
      setState(() {
        _isLoading = false;
        _vehicles = [];
        _loadError =
            'No backend vehicle found for this account yet. Add a vehicle before creating rides.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _vehicles = vehicles;
      _selectedVehicleId = selectedVehicleId;
      _seatLimit = seatLimit.clamp(1, 10).toInt();
      _availableSeats = _availableSeats.clamp(1, _seatLimit).toInt();
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isResolvingPickup = true);
    try {
      final location = await LocationService.getCurrentLocation();
      final address = await LocationService.reverseGeocode(location);
      if (!mounted) return;
      setState(() {
        _pickupLatLng = location;
        _pickupController.text = address;
        _isResolvingPickup = false;
      });
      _refreshFareEstimate();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResolvingPickup = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _useSavedAddress() async {
    final saved = await LocationService.getSavedPickupAddress();

    if (!mounted) return;

    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved address found yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _pickupLatLng = LatLng(
        (saved['lat'] as num).toDouble(),
        (saved['lng'] as num).toDouble(),
      );
      _pickupController.text = saved['address'] as String;
    });
    _refreshFareEstimate();
  }

  Future<void> _openPinDrop() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PinDropScreen(initialLocation: _pickupLatLng),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _pickupLatLng = LatLng(
        (result['lat'] as num).toDouble(),
        (result['lng'] as num).toDouble(),
      );
      _pickupController.text = result['address'] as String;
    });
    _refreshFareEstimate();
  }

  void _onCampusChanged(String? campusName) {
    setState(() => _selectedCampusName = campusName);
    _refreshFareEstimate();
  }

  Future<void> _pickRideDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rideDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null && mounted) {
      setState(() => _rideDate = picked);
    }
  }

  Future<void> _pickRideTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _rideTime,
    );

    if (picked != null && mounted) {
      setState(() => _rideTime = picked);
    }
  }

  Future<void> _refreshFareEstimate() async {
    final campus = _selectedCampus;
    final pickup = _pickupLatLng;
    if (campus == null || pickup == null) {
      if (mounted) {
        setState(() => _estimatedFare = null);
      }
      return;
    }

    final res = await FareApiService.estimateFare(
      startLat: pickup.latitude,
      startLng: pickup.longitude,
      endLat: (campus['lat'] as num).toDouble(),
      endLng: (campus['lng'] as num).toDouble(),
      numRiders: 1,
    );

    if (!mounted) return;

    if (res.success && res.data is Map<String, dynamic>) {
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _estimatedFare = (data['total_fare'] as num?)?.toDouble();
      });
    }
  }

  Map<String, dynamic>? get _selectedCampus {
    if (_selectedCampusName == null) return null;
    for (final campus in _campuses) {
      if (campus['name'] == _selectedCampusName) {
        return campus;
      }
    }
    return null;
  }

  String _formatDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    final displayHour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final displayMinute = time.minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $suffix';
  }

  String _apiDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _apiTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  String _vehicleLabel(Map<String, dynamic> vehicle) {
    final type = vehicle['vehicle_type']?.toString() ?? 'vehicle';
    final prettyType = type == '2_wheeler' ? '2 Wheeler' : '4 Wheeler';
    return '${vehicle['vehicle_number']} • $prettyType';
  }

  Future<void> _submitRide() async {
    if (_selectedVehicleId == null) {
      _showValidationMessage('Select a vehicle first.');
      return;
    }
    if (_pickupLatLng == null || _pickupController.text.trim().isEmpty) {
      _showValidationMessage('Set your starting point first.');
      return;
    }
    final campus = _selectedCampus;
    if (campus == null) {
      _showValidationMessage('Choose a destination campus.');
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await RideApiService.createRide(
      startLat: _pickupLatLng!.latitude,
      startLng: _pickupLatLng!.longitude,
      endLat: (campus['lat'] as num).toDouble(),
      endLng: (campus['lng'] as num).toDouble(),
      startAddress: _pickupController.text.trim(),
      endAddress: campus['name'] as String,
      rideDate: _apiDate(_rideDate),
      rideTime: _apiTime(_rideTime),
      availableSeats: _availableSeats,
      allowedGender: _allowedGender,
      allowedCommunity: _communityController.text.trim(),
      vehicleId: _selectedVehicleId!,
      estimatedFare: _estimatedFare,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (!res.success || res.data is! Map<String, dynamic>) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Failed to create ride.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context, res.data);
  }

  void _showValidationMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : kBackground,
      appBar: AppBar(
        title: const Text(
          'Create Ride',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _loadError != null
          ? _buildErrorState(cardColor)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionCard(
                  cardColor,
                  title: 'Vehicle',
                  child: DropdownButtonFormField<String>(
                    value: _selectedVehicleId,
                    items: _vehicles
                        .map(
                          (vehicle) => DropdownMenuItem<String>(
                            value: vehicle['vehicle_id']?.toString(),
                            child: Text(_vehicleLabel(vehicle)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedVehicleId = value);
                    },
                    decoration: _inputDecoration('Choose the vehicle for this ride'),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  cardColor,
                  title: 'Starting point',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _pickupController,
                        readOnly: true,
                        decoration: _inputDecoration(
                          _isResolvingPickup
                              ? 'Resolving pickup...'
                              : 'Set your ride starting point',
                        ).copyWith(
                          prefixIcon: const Icon(Icons.near_me_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildActionChip(
                            label: 'Current location',
                            icon: Icons.my_location,
                            onTap: _isResolvingPickup ? null : _useCurrentLocation,
                          ),
                          _buildActionChip(
                            label: 'Saved address',
                            icon: Icons.bookmark_border,
                            onTap: _useSavedAddress,
                          ),
                          _buildActionChip(
                            label: 'Pin drop',
                            icon: Icons.location_on_outlined,
                            onTap: _openPinDrop,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  cardColor,
                  title: 'Destination and timing',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedCampusName,
                        items: _campuses
                            .map(
                              (campus) => DropdownMenuItem<String>(
                                value: campus['name'] as String,
                                child: Text(campus['name'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: _onCampusChanged,
                        decoration: _inputDecoration('Select destination campus'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSelectorTile(
                              icon: Icons.calendar_month_outlined,
                              label: 'Ride date',
                              value: _formatDate(_rideDate),
                              onTap: _pickRideDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSelectorTile(
                              icon: Icons.access_time_rounded,
                              label: 'Ride time',
                              value: _formatTimeOfDay(_rideTime),
                              onTap: _pickRideTime,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  cardColor,
                  title: 'Ride settings',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Available seats',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _availableSeats > 1
                                ? () => setState(() => _availableSeats--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$_availableSeats',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          IconButton(
                            onPressed: _availableSeats < _seatLimit
                                ? () => setState(() => _availableSeats++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      Text(
                        'Seat limit from profile: $_seatLimit',
                        style: const TextStyle(color: kMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _allowedGender,
                        items: const [
                          DropdownMenuItem(value: 'any', child: Text('Any')),
                          DropdownMenuItem(value: 'male', child: Text('Male only')),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Female only'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _allowedGender = value);
                          }
                        },
                        decoration: _inputDecoration('Who can join this ride?'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _communityController,
                        decoration: _inputDecoration(
                          'Optional community preference',
                        ).copyWith(prefixIcon: const Icon(Icons.groups_rounded)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_estimatedFare != null)
                  _buildSectionCard(
                    cardColor,
                    title: 'Estimated fare',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.currency_rupee,
                            color: kPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '₹${_estimatedFare!.round()}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                AuthButton(
                  label: 'Publish Ride',
                  icon: Icons.check_circle_outline,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submitRide,
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildErrorState(Color cardColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kCardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_car_outlined, size: 42, color: kMuted),
              const SizedBox(height: 12),
              Text(
                _loadError ?? 'Unable to start ride creation.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadSetupData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    Color cardColor, {
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: kPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: kPrimary),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: kMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: kBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: kCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }
}
