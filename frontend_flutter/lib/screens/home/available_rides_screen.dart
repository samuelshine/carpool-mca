import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../auth/common_widgets.dart';
import '../../services/api_service.dart';

class AvailableRidesScreen extends StatefulWidget {
  final String fromLocation;
  final String toLocation;
  final LatLng fromLatLng;
  final LatLng toLatLng;
  final double? routeDistanceKm;
  final double? routeDurationMinutes;
  final double? fareEstimate;

  const AvailableRidesScreen({
    super.key,
    required this.fromLocation,
    required this.toLocation,
    required this.fromLatLng,
    required this.toLatLng,
    this.routeDistanceKm,
    this.routeDurationMinutes,
    this.fareEstimate,
  });

  @override
  State<AvailableRidesScreen> createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  static const double _destinationMatchRadiusKm = 2.0;

  final Distance _distance = const Distance();
  bool _isLoading = true;
  bool _isRequesting = false;
  bool _isEmailVerified = false;
  String? _requestingRideId;
  String? _errorMessage;
  int _totalOpenRides = 0;
  List<_RideMatch> _matches = [];

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final profileRes = await UserApiService.getMyProfile();
    final res = await RideApiService.listRides();

    if (!mounted) return;

    _isEmailVerified =
        profileRes.success &&
        profileRes.data is Map<String, dynamic> &&
        (profileRes.data as Map<String, dynamic>)['is_email_verified'] == true;

    if (!res.success) {
      setState(() {
        _isLoading = false;
        _errorMessage = res.error ?? 'Unable to load rides right now.';
      });
      return;
    }

    if (res.data is! List) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unexpected ride response from server.';
      });
      return;
    }

    final rides = (res.data as List).whereType<Map>().toList();
    final matches = _buildMatches(rides);

    setState(() {
      _isLoading = false;
      _totalOpenRides = rides.length;
      _matches = matches;
    });
  }

  List<_RideMatch> _buildMatches(List<Map> rides) {
    final matches = <_RideMatch>[];

    for (final ride in rides) {
      final rideId = ride['ride_id']?.toString();
      final availableSeats = (ride['available_seats'] as num?)?.toInt() ?? 0;
      final start = _parseLocation(ride['start_location']);
      final end = _parseLocation(ride['end_location']);

      if (rideId == null || start == null || end == null || availableSeats <= 0) {
        continue;
      }

      final destinationDistanceKm = _distance.as(
        LengthUnit.Kilometer,
        widget.toLatLng,
        end,
      );

      if (destinationDistanceKm > _destinationMatchRadiusKm) {
        continue;
      }

      final pickupDistanceKm = _distance.as(
        LengthUnit.Kilometer,
        widget.fromLatLng,
        start,
      );

      matches.add(
        _RideMatch(
          rideId: rideId,
          startAddress: ride['start_address']?.toString() ?? 'Pickup point',
          endAddress: ride['end_address']?.toString() ?? 'Destination',
          rideDate: ride['ride_date']?.toString() ?? '',
          rideTime: ride['ride_time']?.toString() ?? '',
          availableSeats: availableSeats,
          estimatedFare: (ride['estimated_fare'] as num?)?.toDouble(),
          allowedGender: ride['allowed_gender']?.toString(),
          pickupDistanceKm: pickupDistanceKm,
          destinationDistanceKm: destinationDistanceKm,
        ),
      );
    }

    matches.sort((a, b) {
      final destinationCompare = a.destinationDistanceKm.compareTo(
        b.destinationDistanceKm,
      );
      if (destinationCompare != 0) return destinationCompare;
      return a.pickupDistanceKm.compareTo(b.pickupDistanceKm);
    });

    return matches;
  }

  LatLng? _parseLocation(dynamic raw) {
    if (raw is! Map) return null;

    final lat = raw['latitude'];
    final lng = raw['longitude'];

    if (lat is! num || lng is! num) {
      return null;
    }

    return LatLng(lat.toDouble(), lng.toDouble());
  }

  Future<void> _requestRide(_RideMatch match) async {
    setState(() {
      _isRequesting = true;
      _requestingRideId = match.rideId;
    });

    final res = await RideApiService.requestJoinRide(
      match.rideId,
      pickupLat: widget.fromLatLng.latitude,
      pickupLng: widget.fromLatLng.longitude,
      pickupAddress: widget.fromLocation,
    );

    if (!mounted) return;

    setState(() {
      _isRequesting = false;
      _requestingRideId = null;
    });

    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.error ?? 'Unable to send request right now.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Request Sent',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Your ride request has been sent to the driver. You will be able to continue once it is accepted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  String _formatTime(String rawTime) {
    if (rawTime.isEmpty) return 'Time not set';

    final parts = rawTime.split(':');
    if (parts.length < 2) return rawTime;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return rawTime;

    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $suffix';
  }

  String _formatDate(String rawDate) {
    if (rawDate.isEmpty) return 'Date not set';

    final date = DateTime.tryParse(rawDate);
    if (date == null) return rawDate;

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

    return '${date.day} ${monthNames[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : kBackground,
      appBar: AppBar(
        title: const Text(
          'Available Rides',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMatches,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildQuerySummary(cardColor),
            const SizedBox(height: 16),
            if (!_isEmailVerified)
              _buildAccessNotice(cardColor),
            if (!_isEmailVerified) const SizedBox(height: 16),
            if (_isLoading)
              _buildLoadingCard(cardColor)
            else if (_errorMessage != null)
              _buildErrorCard(cardColor)
            else if (_matches.isEmpty)
              _buildEmptyCard(cardColor)
            else ...[
              Text(
                '${_matches.length} matching ${_matches.length == 1 ? 'ride' : 'rides'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Showing open rides headed to the same destination as your route preview.',
                style: TextStyle(color: kMuted.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 16),
              ..._matches.map((match) => _buildRideCard(match, cardColor)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuerySummary(Color cardColor) {
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
          const Text(
            'Trip request',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            icon: Icons.circle,
            color: kPrimary,
            label: 'Pickup',
            value: widget.fromLocation,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(width: 2, height: 14, color: kCardBorder),
          ),
          _buildSummaryRow(
            icon: Icons.location_on,
            color: Colors.red,
            label: 'Destination',
            value: widget.toLocation,
          ),
          if (widget.fareEstimate != null || widget.routeDurationMinutes != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.fareEstimate != null)
                  _buildMiniChip(
                    Icons.currency_rupee,
                    'Est. ₹${widget.fareEstimate!.round()}',
                  ),
                if (widget.routeDurationMinutes != null)
                  _buildMiniChip(
                    Icons.access_time,
                    '${widget.routeDurationMinutes!.round()} min',
                  ),
                if (widget.routeDistanceKm != null)
                  _buildMiniChip(
                    Icons.straighten,
                    '${widget.routeDistanceKm!.toStringAsFixed(1)} km',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: kPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: kPrimary),
          SizedBox(height: 16),
          Text(
            'Looking for open rides',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'Matching rides headed to your destination',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.orange, size: 40),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadMatches,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            color: kMuted.withValues(alpha: 0.7),
            size: 42,
          ),
          const SizedBox(height: 12),
          const Text(
            'No matching rides right now',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _totalOpenRides == 0
                ? 'There are no open rides at the moment. Try again a little later.'
                : 'We found open rides, but none are headed to this destination yet.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(_RideMatch match, Color cardColor) {
    final isRequestingThisRide =
        _isRequesting && _requestingRideId == match.rideId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${match.availableSeats} ${match.availableSeats == 1 ? 'seat' : 'seats'} left',
                  style: const TextStyle(
                    color: kPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_formatDate(match.rideDate)} • ${_formatTime(match.rideTime)}',
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSummaryRow(
            icon: Icons.circle,
            color: kPrimary,
            label: 'Driver starts from',
            value: match.startAddress,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(width: 2, height: 14, color: kCardBorder),
          ),
          _buildSummaryRow(
            icon: Icons.location_on,
            color: Colors.red,
            label: 'Ride destination',
            value: match.endAddress,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildNeutralChip(
                Icons.near_me_outlined,
                '${match.pickupDistanceKm.toStringAsFixed(1)} km from your pickup',
              ),
              if (match.estimatedFare != null)
                _buildNeutralChip(
                  Icons.currency_rupee,
                  'Ride fare ₹${match.estimatedFare!.round()}',
                ),
              if (match.allowedGender != null)
                _buildNeutralChip(
                  Icons.people_outline,
                  'Allowed: ${match.allowedGender}',
                ),
            ],
          ),
          const SizedBox(height: 14),
          AuthButton(
            label: !_isEmailVerified
                ? 'College Email Verification Required'
                : isRequestingThisRide
                ? 'Sending request...'
                : 'Request This Ride',
            icon: Icons.send_rounded,
            isLoading: isRequestingThisRide,
            onPressed: !_isEmailVerified || _isRequesting
                ? null
                : () => _requestRide(match),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessNotice(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You can browse available rides, but you need a verified Christ University email before you can request a seat.',
              style: TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeutralChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RideMatch {
  final String rideId;
  final String startAddress;
  final String endAddress;
  final String rideDate;
  final String rideTime;
  final int availableSeats;
  final double? estimatedFare;
  final String? allowedGender;
  final double pickupDistanceKm;
  final double destinationDistanceKm;

  const _RideMatch({
    required this.rideId,
    required this.startAddress,
    required this.endAddress,
    required this.rideDate,
    required this.rideTime,
    required this.availableSeats,
    required this.estimatedFare,
    required this.allowedGender,
    required this.pickupDistanceKm,
    required this.destinationDistanceKm,
  });
}
