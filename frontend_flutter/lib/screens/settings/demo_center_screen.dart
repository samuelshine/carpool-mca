import 'package:flutter/material.dart';

import 'package:frontend_flutter/screens/driver/create_ride_screen.dart';
import 'package:frontend_flutter/screens/driver/ride_requests_screen.dart';
import 'package:frontend_flutter/screens/home/available_rides_screen.dart';
import 'package:frontend_flutter/screens/home/ride_directions_screen.dart';
import 'package:frontend_flutter/screens/home/ride_live_screen.dart';
import 'package:frontend_flutter/screens/profile/user_profile.dart';
import 'package:frontend_flutter/screens/profile/verification_screen.dart';
import 'package:frontend_flutter/screens/rides/activity_history_screen.dart';
import 'package:frontend_flutter/screens/rides/rate_ride_screen.dart';
import 'package:frontend_flutter/screens/settings/safety_center_screen.dart';

import '../../services/demo_mode_service.dart';

class DemoCenterScreen extends StatelessWidget {
  const DemoCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Demo Center',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroCard(context, cardColor),
          const SizedBox(height: 16),
          _buildSectionCard(
            cardColor: cardColor,
            title: 'Rider Journey',
            subtitle:
                'Show route selection, ride matching, and the in-ride experience without needing a moving car.',
            actions: [
              _DemoAction(
                label: 'Route Preview',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RideDirectionsScreen(
                      fromLocation: DemoModeData.riderPickupLabel,
                      toLocation: DemoModeData.riderDestinationLabel,
                      fromLatLng: DemoModeData.riderPickupLatLng,
                      toLatLng: DemoModeData.riderDestinationLatLng,
                    ),
                  ),
                ),
              ),
              _DemoAction(
                label: 'Ride Matches',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AvailableRidesScreen(
                      fromLocation: DemoModeData.riderPickupLabel,
                      toLocation: DemoModeData.riderDestinationLabel,
                      fromLatLng: DemoModeData.riderPickupLatLng,
                      toLatLng: DemoModeData.riderDestinationLatLng,
                      demoMode: true,
                    ),
                  ),
                ),
              ),
              _DemoAction(
                label: 'Live Ride',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RideLiveScreen(
                      fromLocation: DemoModeData.riderPickupLabel,
                      toLocation: DemoModeData.riderDestinationLabel,
                      fromLatLng: DemoModeData.riderPickupLatLng,
                      toLatLng: DemoModeData.riderDestinationLatLng,
                      fareEstimate: 92,
                      distanceKm: 4.8,
                      durationMinutes: 17,
                      driverName: DemoModeData.driverName,
                      demoMode: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            cardColor: cardColor,
            title: 'Driver Operations',
            subtitle:
                'Walk through creating a ride, reviewing join requests, and controlling live-trip state from the driver side.',
            actions: [
              _DemoAction(
                label: 'Create Ride',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateRideScreen(demoMode: true),
                  ),
                ),
              ),
              _DemoAction(
                label: 'Requests',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RideRequestsScreen(
                      rideId: DemoModeData.liveRideId,
                      demoMode: true,
                    ),
                  ),
                ),
              ),
              _DemoAction(
                label: 'Driver Live',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RideLiveScreen(
                      fromLocation: DemoModeData.driverPickupLabel,
                      toLocation: DemoModeData.riderDestinationLabel,
                      fromLatLng: DemoModeData.driverPickupLatLng,
                      toLatLng: DemoModeData.riderDestinationLatLng,
                      fareEstimate: 84,
                      distanceKm: 6.2,
                      durationMinutes: 21,
                      driverName: DemoModeData.driverName,
                      demoMode: true,
                      initialDriverView: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            cardColor: cardColor,
            title: 'Safety And Trust',
            subtitle:
                'Cover emergency readiness, ride history, and the post-trip rating loop with demo-ready sample data.',
            actions: [
              _DemoAction(
                label: 'Safety Center',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SafetyCenterScreen(demoMode: true),
                  ),
                ),
              ),
              _DemoAction(
                label: 'Activity',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ActivityHistoryScreen(demoMode: true),
                  ),
                ),
              ),
              _DemoAction(
                label: 'Rate Ride',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RateRideScreen(
                      rideId: 'demo-history-completed-001',
                      ratedUserId: DemoModeData.driverUserId,
                      ratedUserName: DemoModeData.driverName,
                      isDriver: true,
                      demoMode: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            cardColor: cardColor,
            title: 'Account And Verification',
            subtitle:
                'Use seeded profile and verification states to talk through onboarding, identity checks, and driver readiness.',
            actions: [
              _DemoAction(
                label: 'Profile',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserProfileScreen(demoMode: true),
                  ),
                ),
              ),
              _DemoAction(
                label: 'Verification',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VerificationScreen(demoMode: true),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.smart_display,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Demo Mode is active',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'These shortcuts use seeded demo data for flows that normally depend on real rides, requests, or emergency events. You can move between rider and driver storytelling without changing accounts.',
            style: TextStyle(color: Colors.black87, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required Color cardColor,
    required String title,
    required String subtitle,
    required List<_DemoAction> actions,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
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
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: actions
                .map(
                  (action) => OutlinedButton(
                    onPressed: action.onTap,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(action.label),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DemoAction {
  final String label;
  final VoidCallback onTap;

  const _DemoAction({required this.label, required this.onTap});
}
