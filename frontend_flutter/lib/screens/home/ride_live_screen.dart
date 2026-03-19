import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../auth/common_widgets.dart';
import '../rides/rate_ride_screen.dart';
import '../../services/api_service.dart';
import '../../services/demo_mode_service.dart';
import '../../services/location_service.dart';
import '../../services/ride_simulation_service.dart';
import '../../services/routing_service.dart';

enum _RideLivePhase {
  waitingDriverStart,
  driverToPickup,
  pickupReached,
  pickupConfirmed,
  enRoute,
  completed,
  cancelled,
}

class RideLiveScreen extends StatefulWidget {
  final String fromLocation;
  final String toLocation;
  final LatLng fromLatLng;
  final LatLng toLatLng;
  final double? distanceKm;
  final double? durationMinutes;
  final double? fareEstimate;
  final String? rideId;
  final String? driverUserId;
  final String? driverName;
  final bool demoMode;
  final bool initialDriverView;

  const RideLiveScreen({
    super.key,
    required this.fromLocation,
    required this.toLocation,
    required this.fromLatLng,
    required this.toLatLng,
    this.distanceKm,
    this.durationMinutes,
    this.fareEstimate,
    this.rideId,
    this.driverUserId,
    this.driverName,
    this.demoMode = false,
    this.initialDriverView = false,
  });

  @override
  State<RideLiveScreen> createState() => _RideLiveScreenState();
}

class _RideLiveScreenState extends State<RideLiveScreen> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  final TextEditingController _otpController = TextEditingController();

  RideSimulationService? _demoSimulation;
  Timer? _trackingPollTimer;
  StreamSubscription<LatLng>? _locationSubscription;

  bool _isLoading = true;
  bool _isSubmittingStatus = false;
  bool _isVerifyingOtp = false;
  bool _isSharingLocation = false;
  bool _isDriverView = false;

  String? _errorMessage;
  String? _currentUserId;
  String? _rideStatus;
  String? _driverUserId;
  String? _driverName;
  String? _vehicleNumber;
  String? _pickupOtp;
  String? _viewerParticipantId;
  bool _viewerPickedUp = false;

  LatLng? _driverPosition;
  LatLng? _rideStartLatLng;
  LatLng? _rideEndLatLng;

  List<LatLng> _prePickupRoute = [];
  List<LatLng> _destinationRoute = [];
  List<Map<String, dynamic>> _participants = [];

  final String _demoPickupOtp = _generateOtp();
  bool _hasFittedMap = false;

  bool get _isDemoMode => widget.demoMode;
  bool get _hasRealRide => widget.rideId != null && !_isDemoMode;

  static String _generateOtp() {
    return '${Random().nextInt(9000) + 1000}';
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _demoSimulation?.dispose();
    _trackingPollTimer?.cancel();
    _locationSubscription?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (_hasRealRide) {
      await _initializeRealRide();
      return;
    }

    if (_isDemoMode) {
      await _initializeDemoRide();
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Live tracking needs a real ride context unless demo mode is enabled.';
      });
    }
  }

  Future<void> _initializeRealRide() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final profileRes = await UserApiService.getMyProfile();
    final trackingRes = await RideApiService.getTrackingInfo(widget.rideId!);

    if (!mounted) return;

    if (!profileRes.success ||
        !trackingRes.success ||
        trackingRes.data is! Map) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            trackingRes.error ??
            profileRes.error ??
            'Unable to load the live ride right now.';
      });
      return;
    }

    _currentUserId = profileRes.data?['user_id']?.toString();
    _applyTrackingPayload(Map<String, dynamic>.from(trackingRes.data as Map));

    if (_isDriverView) {
      await _loadParticipants();
    }

    await _ensureRoutes();
    _recalculateProgress();

    if (!mounted) return;

    setState(() => _isLoading = false);
    _fitMapToCurrentContext();
    _startTrackingPolling();

    if (_shouldShareDriverLocation) {
      await _startDriverLocationSharing();
    }
  }

  Future<void> _refreshRealRideState({bool silent = true}) async {
    if (!_hasRealRide || widget.rideId == null) return;

    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final trackingRes = await RideApiService.getTrackingInfo(widget.rideId!);
    if (!mounted) return;

    if (!trackingRes.success || trackingRes.data is! Map) {
      if (!silent) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              trackingRes.error ?? 'Unable to refresh the live ride right now.';
        });
      }
      return;
    }

    _applyTrackingPayload(Map<String, dynamic>.from(trackingRes.data as Map));

    if (_isDriverView) {
      await _loadParticipants();
    }

    await _ensureRoutes();
    _recalculateProgress();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _errorMessage = null;
    });

    if (_shouldShareDriverLocation) {
      await _startDriverLocationSharing();
    } else {
      await _stopDriverLocationSharing(clearRemote: false);
    }
  }

  void _applyTrackingPayload(Map<String, dynamic> tracking) {
    final driver = tracking['driver'];
    final vehicle = tracking['vehicle'];
    final viewerParticipant = tracking['viewer_participant'];

    _driverUserId = driver is Map
        ? driver['user_id']?.toString()
        : widget.driverUserId;
    _driverName = driver is Map
        ? driver['full_name']?.toString()
        : widget.driverName;
    _vehicleNumber = vehicle is Map
        ? vehicle['vehicle_number']?.toString()
        : null;

    _rideStatus = tracking['status']?.toString() ?? 'open';
    _rideStartLatLng =
        _parseLatLng(tracking['start_location']) ?? widget.fromLatLng;
    _rideEndLatLng = _parseLatLng(tracking['end_location']) ?? widget.toLatLng;

    final driverLocation = _parseLatLng(tracking['driver_location']);
    _driverPosition = driverLocation ?? _driverPosition ?? _rideStartLatLng;

    final isCurrentUserDriver =
        _currentUserId != null && _driverUserId == _currentUserId;
    _isDriverView = isCurrentUserDriver;

    if (viewerParticipant is Map) {
      _viewerParticipantId = viewerParticipant['participant_id']?.toString();
      _viewerPickedUp = viewerParticipant['is_picked_up'] == true;
      _pickupOtp =
          viewerParticipant['pickup_otp']?.toString() ??
          tracking['pickup_otp']?.toString();
    } else {
      _viewerParticipantId = null;
      _viewerPickedUp = false;
      _pickupOtp = tracking['pickup_otp']?.toString();
    }
  }

  Future<void> _loadParticipants() async {
    if (!_hasRealRide || widget.rideId == null || !_isDriverView) return;

    final res = await RideApiService.getRideParticipants(widget.rideId!);
    if (!mounted || !res.success || res.data is! List) return;

    _participants = (res.data as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _ensureRoutes() async {
    final pickupTarget = _currentPickupTarget;
    final routeStart = _rideStartLatLng ?? widget.fromLatLng;
    final destination = _rideEndLatLng ?? widget.toLatLng;

    try {
      if (pickupTarget != null) {
        final toPickup = await RoutingService.getRoute(
          routeStart,
          pickupTarget,
        );
        if (mounted) {
          _prePickupRoute = toPickup.points;
        }
      }

      final toDest = await RoutingService.getRoute(
        pickupTarget ?? widget.fromLatLng,
        destination,
      );
      if (mounted) {
        _destinationRoute = toDest.points;
      }
    } catch (_) {
      // Route rendering is best-effort; status flow should still work.
    }
  }

  void _startTrackingPolling() {
    _trackingPollTimer?.cancel();
    _trackingPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshRealRideState();
    });
  }

  Future<void> _startDriverLocationSharing() async {
    if (!_hasRealRide ||
        widget.rideId == null ||
        !_isDriverView ||
        _isSharingLocation) {
      return;
    }

    _isSharingLocation = true;

    try {
      final initial = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() => _driverPosition = initial);
      }
      _recalculateProgress();
      await RideApiService.updateDriverLocation(
        widget.rideId!,
        latitude: initial.latitude,
        longitude: initial.longitude,
      );
    } catch (_) {
      // If GPS is unavailable, polling and manual status updates still work.
    }

    _locationSubscription?.cancel();
    _locationSubscription =
        LocationService.getPositionStream(distanceFilter: 15).listen((
          position,
        ) async {
          if (!mounted || widget.rideId == null) return;

          setState(() => _driverPosition = position);
          _recalculateProgress();

          await RideApiService.updateDriverLocation(
            widget.rideId!,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        });
  }

  Future<void> _stopDriverLocationSharing({required bool clearRemote}) async {
    _isSharingLocation = false;
    final subscription = _locationSubscription;
    if (subscription != null) {
      await subscription.cancel();
    }
    _locationSubscription = null;

    if (clearRemote && _hasRealRide && widget.rideId != null) {
      await RideApiService.clearDriverLocation(widget.rideId!);
    }
  }

  Future<void> _initializeDemoRide() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isDriverView = widget.initialDriverView;
      _driverName = widget.driverName ?? 'Demo Driver';
      _driverUserId = widget.driverUserId;
      _pickupOtp = _demoPickupOtp;
      _rideStatus = 'driver_arriving';
    });

    final driverStart = LatLng(
      widget.fromLatLng.latitude + 0.015,
      widget.fromLatLng.longitude - 0.012,
    );

    try {
      final toPickup = await RoutingService.getRoute(
        driverStart,
        widget.fromLatLng,
      );
      final toDest = await RoutingService.getRoute(
        widget.fromLatLng,
        widget.toLatLng,
      );

      if (!mounted) return;

      setState(() {
        _driverPosition = driverStart;
        _rideStartLatLng = driverStart;
        _rideEndLatLng = widget.toLatLng;
        _prePickupRoute = toPickup.points;
        _destinationRoute = toDest.points;
        _isLoading = false;
      });

      _startDemoPickupSimulation();
      _fitMapToCurrentContext();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to start demo ride: $e';
      });
    }
  }

  void _startDemoPickupSimulation() {
    _demoSimulation?.dispose();
    _rideStatus = 'driver_arriving';

    _demoSimulation = RideSimulationService(
      routePoints: List<LatLng>.from(_prePickupRoute),
      speedKmh: 40,
      onUpdate: (pos, progress, _) {
        if (!mounted) return;
        setState(() {
          _driverPosition = pos;
          _recalculateDemoProgress(progress);
        });
      },
      onPhaseComplete: () {
        if (!mounted) return;
        setState(() {
          _rideStatus = 'driver_arrived';
          _driverPosition = widget.fromLatLng;
        });
      },
    );

    _demoSimulation!.start();
  }

  void _startDemoDestinationSimulation() {
    _demoSimulation?.dispose();
    _rideStatus = 'ongoing';

    _demoSimulation = RideSimulationService(
      routePoints: List<LatLng>.from(_destinationRoute),
      speedKmh: 35,
      onUpdate: (pos, progress, _) {
        if (!mounted) return;
        setState(() {
          _driverPosition = pos;
          _recalculateDemoProgress(progress);
        });
      },
      onPhaseComplete: () {
        if (!mounted) return;
        setState(() {
          _rideStatus = 'completed';
          _driverPosition = widget.toLatLng;
        });
      },
    );

    _demoSimulation!.start();
  }

  void _recalculateDemoProgress(double progress) {
    _progress = progress.clamp(0.0, 1.0).toDouble();
  }

  double _progress = 0;

  void _recalculateProgress() {
    if (_isDemoMode) return;

    final current = _driverPosition;
    if (current == null) return;

    final phase = _currentPhase;
    final pickupTarget = _currentPickupTarget ?? widget.fromLatLng;
    final destination = _rideEndLatLng ?? widget.toLatLng;
    late final LatLng target;
    late final LatLng start;

    switch (phase) {
      case _RideLivePhase.waitingDriverStart:
      case _RideLivePhase.driverToPickup:
      case _RideLivePhase.pickupReached:
        start = _rideStartLatLng ?? pickupTarget;
        target = pickupTarget;
        break;
      case _RideLivePhase.pickupConfirmed:
      case _RideLivePhase.enRoute:
      case _RideLivePhase.completed:
      case _RideLivePhase.cancelled:
        start = pickupTarget;
        target = destination;
        break;
    }

    final totalKm = _distance.as(LengthUnit.Kilometer, start, target);
    if (phase == _RideLivePhase.completed) {
      _progress = 1;
      return;
    }

    if (totalKm <= 0.05) {
      _progress = 0;
      return;
    }

    final remainingKm = _distance.as(LengthUnit.Kilometer, current, target);
    _progress = (1 - (remainingKm / totalKm)).clamp(0.0, 1.0).toDouble();
  }

  LatLng? get _currentPickupTarget {
    if (_isDriverView) {
      final pending = _nextPendingParticipant;
      final lat = (pending?['pickup_lat'] as num?)?.toDouble();
      final lng = (pending?['pickup_lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    return widget.fromLatLng;
  }

  Map<String, dynamic>? get _nextPendingParticipant {
    for (final participant in _participants) {
      if (participant['is_picked_up'] != true) {
        return participant;
      }
    }
    return null;
  }

  bool get _shouldShareDriverLocation {
    return _hasRealRide &&
        _isDriverView &&
        const {
          'driver_arriving',
          'driver_arrived',
          'rider_picked_up',
          'ongoing',
        }.contains(_rideStatus);
  }

  _RideLivePhase get _currentPhase {
    final status = _rideStatus ?? 'open';

    if (status == 'cancelled') return _RideLivePhase.cancelled;
    if (status == 'completed') return _RideLivePhase.completed;

    if (!_isDriverView && _viewerPickedUp && status == 'driver_arrived') {
      return _RideLivePhase.enRoute;
    }

    switch (status) {
      case 'open':
        return _RideLivePhase.waitingDriverStart;
      case 'driver_arriving':
        return _RideLivePhase.driverToPickup;
      case 'driver_arrived':
        return _RideLivePhase.pickupReached;
      case 'rider_picked_up':
        return _isDriverView
            ? _RideLivePhase.pickupConfirmed
            : _RideLivePhase.enRoute;
      case 'ongoing':
        return _RideLivePhase.enRoute;
      default:
        return _RideLivePhase.waitingDriverStart;
    }
  }

  Future<void> _handleStatusUpdate(String status) async {
    if (_isSubmittingStatus) return;

    if (_isDemoMode) {
      _handleDemoStatus(status);
      return;
    }

    if (!_hasRealRide || widget.rideId == null) return;

    setState(() => _isSubmittingStatus = true);
    final res = await RideApiService.updateRideStatus(widget.rideId!, status);

    if (!mounted) return;

    if (!res.success) {
      setState(() => _isSubmittingStatus = false);
      _showSnackBar(
        res.error ?? 'Unable to update ride status.',
        isError: true,
      );
      return;
    }

    if (status == 'completed' || status == 'cancelled') {
      await _stopDriverLocationSharing(clearRemote: true);
    }

    setState(() {
      _rideStatus = status;
      _isSubmittingStatus = false;
    });

    if (_shouldShareDriverLocation) {
      await _startDriverLocationSharing();
    }

    await _refreshRealRideState();
  }

  void _handleDemoStatus(String status) {
    switch (status) {
      case 'driver_arriving':
        _startDemoPickupSimulation();
        break;
      case 'driver_arrived':
        _demoSimulation?.stop();
        setState(() {
          _rideStatus = 'driver_arrived';
          _driverPosition = widget.fromLatLng;
        });
        break;
      case 'ongoing':
        _startDemoDestinationSimulation();
        break;
      case 'completed':
        _demoSimulation?.stop();
        setState(() {
          _rideStatus = 'completed';
          _driverPosition = widget.toLatLng;
          _progress = 1;
        });
        break;
      case 'cancelled':
        _demoSimulation?.stop();
        setState(() => _rideStatus = 'cancelled');
        break;
    }
  }

  Future<void> _verifyPickupOtp() async {
    if (_isVerifyingOtp) return;

    if (_isDemoMode) {
      _verifyDemoPickupOtp();
      return;
    }

    if (!_hasRealRide || widget.rideId == null) return;

    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      _showSnackBar('Enter the 4-digit OTP first.', isError: true);
      return;
    }

    final participantId =
        _nextPendingParticipant?['participant_id']?.toString() ??
        _viewerParticipantId;

    setState(() => _isVerifyingOtp = true);
    final res = await RideApiService.verifyPickupOtp(
      widget.rideId!,
      otp,
      participantId: participantId,
    );

    if (!mounted) return;

    setState(() => _isVerifyingOtp = false);

    if (!res.success) {
      _showSnackBar(res.error ?? 'OTP verification failed.', isError: true);
      return;
    }

    _otpController.clear();
    await _loadParticipants();

    if (_isDriverView && _nextPendingParticipant == null) {
      await _handleStatusUpdate('rider_picked_up');
    } else {
      await _refreshRealRideState();
    }

    _showSnackBar('Pickup verified successfully.');
  }

  void _verifyDemoPickupOtp() {
    if (_otpController.text.trim() != _demoPickupOtp) {
      _showSnackBar('Invalid demo OTP.', isError: true);
      return;
    }

    _otpController.clear();
    setState(() => _rideStatus = 'rider_picked_up');
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _handleDemoStatus('ongoing');
      }
    });
  }

  Future<void> _triggerSOS() async {
    if (_hasRealRide && widget.rideId == null) {
      _showSnackBar('Cannot trigger SOS. Ride details are invalid.', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'Emergency SOS',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'This will send an SOS alert with your current location. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Send SOS',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final pos = _driverPosition ?? widget.fromLatLng;

    if (_hasRealRide && widget.rideId != null) {
      final res = await SOSApiService.trigger(
        rideId: widget.rideId!,
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      _showSnackBar(
        res.success
            ? 'SOS alert sent. Emergency contacts have been notified.'
            : res.error ?? 'Unable to send the SOS alert right now.',
        isError: !res.success,
      );
      return;
    }

    _showSnackBar('SOS noted. Demo mode does not notify real contacts.');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  LatLng? _parseLatLng(dynamic raw) {
    if (raw is! Map) return null;
    final lat = raw['latitude'];
    final lng = raw['longitude'];
    if (lat is! num || lng is! num) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  String get _effectiveDriverName =>
      _driverName ?? widget.driverName ?? 'Driver';

  void _fitMapToCurrentContext() {
    if (_hasFittedMap) return;
    _hasFittedMap = true;
    final points = [
      widget.fromLatLng,
      widget.toLatLng,
      if (_driverPosition != null) _driverPosition!,
      ..._prePickupRoute,
      ..._destinationRoute,
    ];
    _fitMapToRoute(points);
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : Column(
                children: [
                  _buildTopBar(cardColor),
                  _buildStatusCard(cardColor),
                  Expanded(
                    child: _errorMessage != null
                        ? _buildErrorState(cardColor)
                        : _buildMap(cardColor),
                  ),
                  _buildBottomPanel(cardColor),
                ],
              ),
      ),
      floatingActionButton: _isDemoMode
          ? FloatingActionButton.small(
              onPressed: () => setState(() => _isDriverView = !_isDriverView),
              backgroundColor: _isDriverView
                  ? const Color(0xFF6366F1)
                  : kPrimary,
              child: Icon(
                _isDriverView ? Icons.person : Icons.directions_car,
                color: Colors.white,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: kPrimary),
          SizedBox(height: 16),
          Text(
            'Setting up live ride...',
            style: TextStyle(
              color: kMuted,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(Color cardColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(bottom: BorderSide(color: kCardBorder)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDemoMode
                      ? (_isDriverView ? 'DEMO DRIVER' : 'DEMO RIDER')
                      : (_isDriverView ? 'DRIVER VIEW' : 'RIDER VIEW'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: _isDriverView ? const Color(0xFF6366F1) : kPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _titleForPhase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          _buildPhaseBadge(),
        ],
      ),
    );
  }

  Widget _buildPhaseBadge() {
    final phase = _currentPhase;
    final color = switch (phase) {
      _RideLivePhase.completed => Colors.green,
      _RideLivePhase.cancelled => Colors.red,
      _RideLivePhase.pickupReached => Colors.orange,
      _RideLivePhase.pickupConfirmed => const Color(0xFF6366F1),
      _ => kPrimary,
    };

    final label = switch (phase) {
      _RideLivePhase.waitingDriverStart => 'Ready',
      _RideLivePhase.driverToPickup => '${(_progress * 100).round()}%',
      _RideLivePhase.pickupReached => 'At Pickup',
      _RideLivePhase.pickupConfirmed => 'Picked Up',
      _RideLivePhase.enRoute => '${(_progress * 100).round()}%',
      _RideLivePhase.completed => 'Done',
      _RideLivePhase.cancelled => 'Cancelled',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusCard(Color cardColor) {
    final pickupLabel =
        _isDriverView && _nextPendingParticipant?['pickup_address'] != null
        ? _nextPendingParticipant!['pickup_address'].toString()
        : widget.fromLocation;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.circle,
            iconColor: kPrimary,
            label: 'Pickup',
            location: pickupLabel,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(width: 2, height: 16, color: kCardBorder),
          ),
          _buildLocationRow(
            icon: Icons.location_on,
            iconColor: Colors.red,
            label: 'Destination',
            location: widget.toLocation,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.distanceKm != null)
                _buildMetricChip(
                  icon: Icons.straighten,
                  label: '${widget.distanceKm!.toStringAsFixed(1)} km',
                  color: kPrimary,
                ),
              if (_etaMinutes() != null)
                _buildMetricChip(
                  icon: Icons.access_time,
                  label: '${_etaMinutes()} min',
                  color: const Color(0xFF6366F1),
                ),
              if (_vehicleNumber != null)
                _buildMetricChip(
                  icon: Icons.directions_car,
                  label: _vehicleNumber!,
                  color: Colors.orange,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color cardColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kCardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 44),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load the ride.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _initialize,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(Color cardColor) {
    final currentRoute = switch (_currentPhase) {
      _RideLivePhase.waitingDriverStart ||
      _RideLivePhase.driverToPickup ||
      _RideLivePhase.pickupReached => _prePickupRoute,
      _RideLivePhase.pickupConfirmed ||
      _RideLivePhase.enRoute ||
      _RideLivePhase.completed ||
      _RideLivePhase.cancelled => _destinationRoute,
    };

    final pickupTarget = _currentPickupTarget ?? widget.fromLatLng;
    final destination = _rideEndLatLng ?? widget.toLatLng;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kCardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.fromLatLng,
              initialZoom: 13,
              onMapReady: _fitMapToCurrentContext,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.uniride.carpool',
              ),
              if (currentRoute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: currentRoute,
                      strokeWidth: 5,
                      color: kPrimary.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: pickupTarget,
                    width: 96,
                    height: 48,
                    child: _buildMapPin(
                      icon: Icons.trip_origin,
                      color: kPrimary,
                      label: 'Pickup',
                    ),
                  ),
                  Marker(
                    point: destination,
                    width: 96,
                    height: 48,
                    child: _buildMapPin(
                      icon: Icons.flag,
                      color: Colors.red,
                      label: 'Dest',
                    ),
                  ),
                  if (_driverPosition != null)
                    Marker(
                      point: _driverPosition!,
                      width: 46,
                      height: 46,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_currentPhase == _RideLivePhase.driverToPickup ||
            _currentPhase == _RideLivePhase.enRoute)
          Positioned(
            right: 24,
            bottom: 18,
            child: GestureDetector(
              onTap: _triggerSOS,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.white, size: 22),
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomPanel(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: kCardBorder)),
      ),
      child: _buildPhaseAction(),
    );
  }

  Widget _buildPhaseAction() {
    return switch (_currentPhase) {
      _RideLivePhase.waitingDriverStart =>
        _isDriverView
            ? _buildDriverReadyToStart()
            : _buildRiderWaitingToStart(),
      _RideLivePhase.driverToPickup =>
        _isDriverView
            ? _buildDriverNavigatingToPickup()
            : _buildRiderWaitingForDriver(),
      _RideLivePhase.pickupReached =>
        _isDriverView ? _buildDriverOtpEntry() : _buildRiderShowOtp(),
      _RideLivePhase.pickupConfirmed => _buildPickupConfirmed(),
      _RideLivePhase.enRoute =>
        _isDriverView
            ? _buildDriverNavigatingToDestination()
            : _buildRiderEnRoute(),
      _RideLivePhase.completed => _buildRideComplete(),
      _RideLivePhase.cancelled => _buildRideCancelled(),
    };
  }

  Widget _buildDriverReadyToStart() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ride ready to begin',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          _nextPendingParticipant?['pickup_address']?.toString() ??
              'Start heading toward the pickup point when you are ready.',
          style: const TextStyle(color: kMuted),
        ),
        const SizedBox(height: 14),
        AuthButton(
          label: 'Start Pickup',
          icon: Icons.navigation,
          isLoading: _isSubmittingStatus,
          onPressed: () => _handleStatusUpdate('driver_arriving'),
        ),
      ],
    );
  }

  Widget _buildRiderWaitingToStart() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Waiting for $_effectiveDriverName to start',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your request has been accepted. Live tracking will start once the driver begins the ride.',
          style: TextStyle(color: kMuted),
        ),
      ],
    );
  }

  Widget _buildDriverNavigatingToPickup() {
    final passengerName =
        _nextPendingParticipant?['full_name']?.toString() ?? 'rider';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.navigation, color: Color(0xFF6366F1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Heading to $passengerName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'ETA: ${_etaMinutes() ?? 1} min',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: kBackground,
            color: const Color(0xFF6366F1),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        AuthButton(
          label: "I've Arrived",
          icon: Icons.location_on,
          isLoading: _isSubmittingStatus,
          onPressed: () => _handleStatusUpdate('driver_arrived'),
        ),
      ],
    );
  }

  Widget _buildRiderWaitingForDriver() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.directions_car, color: kPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_effectiveDriverName is on the way',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'ETA: ${_etaMinutes() ?? 1} min',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: kBackground,
            color: kPrimary,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverOtpEntry() {
    final passenger = _nextPendingParticipant;
    final passengerName = passenger?['full_name']?.toString() ?? 'rider';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify $passengerName\'s pickup OTP',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        if (passenger?['pickup_address'] != null) ...[
          const SizedBox(height: 6),
          Text(
            passenger!['pickup_address'].toString(),
            style: const TextStyle(color: kMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kCardBorder),
                ),
                child: TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    hintText: '• • • •',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isVerifyingOtp ? null : _verifyPickupOtp,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isVerifyingOtp ? kMuted : kPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isVerifyingOtp
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.check, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRiderShowOtp() {
    final code = _pickupOtp;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: kPrimary, size: 32),
          const SizedBox(height: 8),
          const Text(
            'Your driver has arrived',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            code == null
                ? 'Waiting for your pickup code to sync.'
                : 'Share this code with your driver.',
            style: const TextStyle(color: kMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (code != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickupConfirmed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pickup confirmed',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 6),
        const Text(
          'All riders are on board. Start the destination leg when you are ready.',
          style: TextStyle(color: kMuted),
        ),
        const SizedBox(height: 14),
        AuthButton(
          label: 'Start to Destination',
          icon: Icons.flag,
          isLoading: _isSubmittingStatus,
          onPressed: () => _handleStatusUpdate('ongoing'),
        ),
      ],
    );
  }

  Widget _buildDriverNavigatingToDestination() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.flag, color: kPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Heading to ${widget.toLocation}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ETA: ${_etaMinutes() ?? 1} min',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: kBackground,
            color: kPrimary,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        AuthButton(
          label: 'Complete Ride',
          icon: Icons.check_circle,
          isLoading: _isSubmittingStatus,
          onPressed: () => _handleStatusUpdate('completed'),
        ),
      ],
    );
  }

  Widget _buildRiderEnRoute() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.navigation, color: Color(0xFF6366F1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Heading to ${widget.toLocation}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ETA: ${_etaMinutes() ?? 1} min',
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: kBackground,
            color: const Color(0xFF6366F1),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildRideComplete() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration, color: Colors.green, size: 36),
          const SizedBox(height: 8),
          Text(
            _isDriverView ? 'Ride complete' : 'You have arrived',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            widget.toLocation,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted),
          ),
          if (widget.fareEstimate != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Fare: ₹${widget.fareEstimate!.round()}',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AuthButton(
            label: 'Rate Ride',
            icon: Icons.star,
            onPressed: _openRating,
          ),
        ],
      ),
    );
  }

  Future<void> _openRating() async {
    if (_isDriverView) {
      _showSnackBar(
        _isDemoMode
            ? 'Driver-side rating is available from the demo Activity screen.'
            : 'Driver ratings are available from your Activity history.',
      );
      return;
    }

    if (_isDemoMode) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => RateRideScreen(
            rideId: widget.rideId ?? 'demo-history-completed-001',
            ratedUserId: _driverUserId ?? DemoModeData.driverUserId,
            ratedUserName: _effectiveDriverName,
            isDriver: true,
            demoMode: true,
          ),
        ),
      );
      return;
    }

    _showSnackBar('Open Activity to submit your ride rating.');
  }

  Widget _buildRideCancelled() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel_outlined, color: Colors.red, size: 36),
          SizedBox(height: 8),
          Text(
            'Ride cancelled',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          SizedBox(height: 4),
          Text(
            'This ride is no longer active.',
            style: TextStyle(color: kMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _titleForPhase() {
    return switch (_currentPhase) {
      _RideLivePhase.waitingDriverStart =>
        _isDriverView ? 'Ready to Start' : 'Waiting for Driver',
      _RideLivePhase.driverToPickup =>
        _isDriverView ? 'Navigate to Pickup' : 'Driver Approaching',
      _RideLivePhase.pickupReached =>
        _isDriverView ? 'Verify Rider' : 'Driver Arrived',
      _RideLivePhase.pickupConfirmed => 'Pickup Confirmed',
      _RideLivePhase.enRoute => 'En Route',
      _RideLivePhase.completed => 'Arrived',
      _RideLivePhase.cancelled => 'Ride Cancelled',
    };
  }

  int? _etaMinutes() {
    if (_currentPhase == _RideLivePhase.completed ||
        _currentPhase == _RideLivePhase.cancelled) {
      return 0;
    }

    final current = _driverPosition;
    if (current == null) {
      return widget.durationMinutes?.round();
    }

    final target = switch (_currentPhase) {
      _RideLivePhase.waitingDriverStart ||
      _RideLivePhase.driverToPickup ||
      _RideLivePhase.pickupReached => _currentPickupTarget,
      _RideLivePhase.pickupConfirmed ||
      _RideLivePhase.enRoute ||
      _RideLivePhase.completed ||
      _RideLivePhase.cancelled => _rideEndLatLng ?? widget.toLatLng,
    };

    if (target == null) {
      return widget.durationMinutes?.round();
    }

    final distanceKm = _distance.as(LengthUnit.Kilometer, current, target);
    final speedKmh = switch (_currentPhase) {
      _RideLivePhase.waitingDriverStart ||
      _RideLivePhase.driverToPickup ||
      _RideLivePhase.pickupReached => 28.0,
      _RideLivePhase.pickupConfirmed || _RideLivePhase.enRoute => 32.0,
      _RideLivePhase.completed || _RideLivePhase.cancelled => 1.0,
    };

    return max(1, ((distanceKm / speedKmh) * 60).round());
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String location,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                location,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapPin({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
