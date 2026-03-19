import 'package:flutter/material.dart';
import '../auth/common_widgets.dart';
import '../../services/api_service.dart';
import '../../services/demo_mode_service.dart';
import 'rate_ride_screen.dart';

/// Shows ride history for the current user (as driver and rider).
class ActivityHistoryScreen extends StatefulWidget {
  final bool demoMode;

  const ActivityHistoryScreen({super.key, this.demoMode = false});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _allRides = [];
  String? _errorMessage;
  String? _currentUserId;
  final Map<String, List<Map<String, dynamic>>> _rideRatings = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRides() async {
    setState(() => _isLoading = true);

    if (widget.demoMode) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _allRides = DemoModeData.demoRideHistory();
        _currentUserId = DemoModeData.currentUserId;
        _rideRatings
          ..clear()
          ..addAll(DemoModeData.demoRatingsByRide());
      });
      return;
    }

    final res = await RideApiService.listRideHistory();
    final profileRes = await UserApiService.getMyProfile();

    final rides = res.success && res.data is List
        ? res.data as List
        : <dynamic>[];
    final completedRideIds = rides
        .where((item) => item is Map<String, dynamic>)
        .map((item) => item as Map<String, dynamic>)
        .where((ride) => ride['history_state'] == 'completed')
        .map((ride) => ride['ride_id']?.toString())
        .whereType<String>()
        .toList();

    final ratingResponses = await Future.wait(
      completedRideIds.map((rideId) => RatingApiService.getRideRatings(rideId)),
    );

    final ratingsByRideId = <String, List<Map<String, dynamic>>>{};
    for (var i = 0; i < completedRideIds.length; i++) {
      final response = ratingResponses[i];
      if (response.success && response.data is List) {
        ratingsByRideId[completedRideIds[i]] = (response.data as List)
            .whereType<Map>()
            .map<Map<String, dynamic>>(
              (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
            )
            .toList();
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = res.success ? null : res.error;
        _allRides = rides;
        _currentUserId =
            profileRes.success && profileRes.data is Map<String, dynamic>
            ? (profileRes.data as Map<String, dynamic>)['user_id']?.toString()
            : null;
        _rideRatings
          ..clear()
          ..addAll(ratingsByRideId);
      });
    }
  }

  Future<void> _refreshRideRatings(String rideId) async {
    if (widget.demoMode) return;

    final res = await RatingApiService.getRideRatings(rideId);
    if (!mounted || !res.success || res.data is! List) return;
    setState(() {
      _rideRatings[rideId] = (res.data as List)
          .whereType<Map>()
          .map<Map<String, dynamic>>(
            (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
          )
          .toList();
    });
  }

  bool _hasRatedUser(String rideId, String ratedUserId) {
    if (_currentUserId == null) return false;
    final ratings = _rideRatings[rideId] ?? const <Map<String, dynamic>>[];
    return ratings.any(
      (rating) =>
          rating['rater_id']?.toString() == _currentUserId &&
          rating['rated_user_id']?.toString() == ratedUserId,
    );
  }

  Future<void> _openPassengerRating(Map<String, dynamic> ride) async {
    final rideId = ride['ride_id']?.toString();
    final driverId = ride['driver_id']?.toString();
    if (rideId == null || driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver details are unavailable for this ride.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_hasRatedUser(rideId, driverId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already rated the driver for this ride.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RateRideScreen(
          rideId: rideId,
          ratedUserId: driverId,
          ratedUserName: ride['driver_name']?.toString() ?? 'Driver',
          isDriver: true,
          demoMode: widget.demoMode,
        ),
      ),
    );

    if (submitted == true) {
      await _refreshRideRatings(rideId);
    }
  }

  Future<void> _openDriverRatingSheet(Map<String, dynamic> ride) async {
    final rideId = ride['ride_id']?.toString();
    if (rideId == null) return;

    if (widget.demoMode) {
      final participants = DemoModeData.demoParticipants();
      await showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rate Your Riders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the rider you want to rate for this completed trip.',
                  style: TextStyle(color: kMuted),
                ),
                const SizedBox(height: 12),
                ...participants.map((participant) {
                  final passengerId = participant['user_id']?.toString();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: kPrimary.withValues(alpha: 0.12),
                      child: const Icon(Icons.person, color: kPrimary),
                    ),
                    title: Text(
                      participant['full_name']?.toString() ?? 'Passenger',
                    ),
                    subtitle: const Text('Tap to rate rider'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: passengerId == null
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await Navigator.push<bool>(
                              this.context,
                              MaterialPageRoute(
                                builder: (context) => RateRideScreen(
                                  rideId: rideId,
                                  ratedUserId: passengerId,
                                  ratedUserName:
                                      participant['full_name']?.toString() ??
                                      'Passenger',
                                  isDriver: false,
                                  demoMode: true,
                                ),
                              ),
                            );
                          },
                  );
                }),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final participantsRes = await RideApiService.getRideParticipants(rideId);
    if (!mounted) return;

    if (!participantsRes.success || participantsRes.data is! List) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            participantsRes.error ?? 'Unable to load riders for rating.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final participants = (participantsRes.data as List)
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
        )
        .toList();

    if (participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No confirmed riders found for this completed ride.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rate Your Riders',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose the rider you want to rate for this completed trip.',
                style: TextStyle(color: kMuted),
              ),
              const SizedBox(height: 12),
              ...participants.map((participant) {
                final passengerId = participant['user_id']?.toString();
                final alreadyRated = passengerId != null
                    ? _hasRatedUser(rideId, passengerId)
                    : false;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: kPrimary.withValues(alpha: 0.12),
                    child: const Icon(Icons.person, color: kPrimary),
                  ),
                  title: Text(
                    participant['full_name']?.toString() ?? 'Passenger',
                  ),
                  subtitle: Text(
                    alreadyRated ? 'Rating submitted' : 'Tap to rate rider',
                  ),
                  trailing: alreadyRated
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.chevron_right),
                  onTap: passengerId == null || alreadyRated
                      ? null
                      : () async {
                          Navigator.pop(context);
                          final submitted = await Navigator.push<bool>(
                            this.context,
                            MaterialPageRoute(
                              builder: (context) => RateRideScreen(
                                rideId: rideId,
                                ratedUserId: passengerId,
                                ratedUserName:
                                    participant['full_name']?.toString() ??
                                    'Passenger',
                                isDriver: false,
                                demoMode: widget.demoMode,
                              ),
                            ),
                          );
                          if (submitted == true) {
                            await _refreshRideRatings(rideId);
                          }
                        },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    // Separate into real history states from backend.
    final activeRides = _allRides.where((r) {
      return r['history_state'] == 'active';
    }).toList();

    final requestedRides = _allRides.where((r) {
      return r['history_state'] == 'requested';
    }).toList();

    final completedRides = _allRides.where((r) {
      return r['history_state'] == 'completed';
    }).toList();

    final cancelledRides = _allRides.where((r) {
      return r['history_state'] == 'cancelled';
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
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
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Activity',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              color: cardColor,
              child: TabBar(
                controller: _tabController,
                labelColor: kPrimary,
                unselectedLabelColor: kMuted,
                indicatorColor: kPrimary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(text: 'Active (${activeRides.length})'),
                  Tab(text: 'Requested (${requestedRides.length})'),
                  Tab(text: 'Completed (${completedRides.length})'),
                  Tab(text: 'Cancelled (${cancelledRides.length})'),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: kPrimary),
                    )
                  : _errorMessage != null
                  ? _buildErrorState()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRideList(
                          activeRides,
                          cardColor,
                          isEmpty: 'No active rides',
                        ),
                        _buildRideList(
                          requestedRides,
                          cardColor,
                          isEmpty: 'No requested rides yet',
                        ),
                        _buildRideList(
                          completedRides,
                          cardColor,
                          isEmpty: 'No completed rides yet',
                        ),
                        _buildRideList(
                          cancelledRides,
                          cardColor,
                          isEmpty: 'No cancelled rides',
                        ),
                      ],
                    ),
            ),
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
            const Icon(Icons.error_outline, color: Colors.orange, size: 42),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load ride history.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadRides,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideList(
    List<dynamic> rides,
    Color cardColor, {
    required String isEmpty,
  }) {
    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 48,
              color: kMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(isEmpty, style: const TextStyle(color: kMuted, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRides,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rides.length,
        itemBuilder: (context, index) =>
            _buildRideCard(rides[index], cardColor),
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, Color cardColor) {
    final historyState = ride['history_state'] ?? '';
    final statusLabel = ride['status_label']?.toString() ?? 'UNKNOWN';
    final userRole = ride['user_role']?.toString() ?? 'user';
    final requestStatus = ride['request_status']?.toString();
    final isActive = historyState == 'active';
    final isCompleted = historyState == 'completed';

    final statusColor = switch (historyState) {
      'active' => kPrimary,
      'requested' => requestStatus == 'rejected' ? Colors.red : Colors.orange,
      'completed' => Colors.green,
      'cancelled' => Colors.red,
      _ => kMuted,
    };

    final roleLabel = switch (userRole) {
      'driver' => 'Driver',
      'passenger' => 'Passenger',
      'requester' => 'Request',
      _ => 'Ride',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? kPrimary.withValues(alpha: 0.3) : kCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status + date
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${ride['ride_date'] ?? ''}',
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  roleLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kMuted,
                  ),
                ),
              ),
              if (ride['driver_name'] != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Driver: ${ride['driver_name']}',
                    style: const TextStyle(color: kMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Route
          Row(
            children: [
              const Icon(Icons.circle, color: kPrimary, size: 10),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride['start_address'] ?? 'Start',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(width: 2, height: 12, color: kCardBorder),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 10),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride['end_address'] ?? 'Destination',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Fare if available
          if (ride['estimated_fare'] != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.currency_rupee, size: 14, color: kPrimary),
                const SizedBox(width: 4),
                Text(
                  '₹${ride['estimated_fare']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${ride['available_seats'] ?? 0} seats',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ],

          if (ride['ride_time'] != null || ride['vehicle_number'] != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (ride['ride_time'] != null)
                  Text(
                    'Time: ${ride['ride_time']}',
                    style: const TextStyle(color: kMuted, fontSize: 12),
                  ),
                if (ride['vehicle_number'] != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vehicle: ${ride['vehicle_number']}',
                      style: const TextStyle(color: kMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (isCompleted) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _buildRatingAction(ride),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingAction(Map<String, dynamic> ride) {
    final userRole = ride['user_role']?.toString();
    final rideId = ride['ride_id']?.toString();
    final driverId = ride['driver_id']?.toString();

    if (userRole == 'passenger' && rideId != null && driverId != null) {
      final alreadyRated = _hasRatedUser(rideId, driverId);
      return Row(
        children: [
          Expanded(
            child: Text(
              alreadyRated
                  ? 'You already rated the driver for this ride.'
                  : 'Completed ride. Rate the driver to close the trip loop.',
              style: const TextStyle(color: kMuted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: alreadyRated ? null : () => _openPassengerRating(ride),
            icon: Icon(
              alreadyRated ? Icons.check_circle : Icons.star_outline,
              size: 18,
            ),
            label: Text(alreadyRated ? 'Rated' : 'Rate Driver'),
          ),
        ],
      );
    }

    if (userRole == 'driver' && rideId != null) {
      return Row(
        children: [
          const Expanded(
            child: Text(
              'Completed ride. Rate your confirmed rider or riders.',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => _openDriverRatingSheet(ride),
            icon: const Icon(Icons.star_outline, size: 18),
            label: const Text('Rate Rider'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
