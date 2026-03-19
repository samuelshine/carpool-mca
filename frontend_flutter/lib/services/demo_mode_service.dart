import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DemoModeNotifier extends ChangeNotifier {
  static const String _demoModeKey = 'demoModeEnabled';

  bool _isEnabled = false;

  bool get isEnabled => _isEnabled;

  DemoModeNotifier() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_demoModeKey) ?? false;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoModeKey, value);
    notifyListeners();
  }

  Future<void> toggle() async {
    await setEnabled(!_isEnabled);
  }
}

final demoModeNotifier = DemoModeNotifier();

class DemoModeData {
  static const String currentUserId = 'demo-user-001';
  static const String driverUserId = 'demo-driver-001';
  static const String liveRideId = 'demo-ride-live-001';
  static const String driverName = 'Aarav Nair';
  static const String driverVehicleNumber = 'KA 05 MQ 4421';
  static const String riderPickupLabel = 'BTM Layout 2nd Stage, Bangalore';
  static const String riderDestinationLabel =
      'Christ University - Central Campus';
  static const LatLng riderPickupLatLng = LatLng(12.9166, 77.6101);
  static const LatLng riderDestinationLatLng = LatLng(12.9347, 77.6066);
  static const String driverPickupLabel = 'JP Nagar 4th Phase, Bangalore';
  static const LatLng driverPickupLatLng = LatLng(12.9082, 77.5937);

  static double estimateFare({
    required LatLng start,
    required LatLng end,
    int riders = 1,
  }) {
    const distance = Distance();
    final km = distance.as(LengthUnit.Kilometer, start, end);
    final baseFare = max(75, (km * 10).round());
    return (baseFare / max(riders, 1)).toDouble();
  }

  static Map<String, dynamic> demoProfile() {
    return {
      'user_id': currentUserId,
      'full_name': 'Demo Student',
      'phone_number': '+91 98765 43210',
      'email': 'demo.student@christuniversity.in',
      'community': 'MCA',
      'gender': 'female',
      'is_email_verified': true,
      'is_identity_verified': true,
      'is_driver_verified': true,
    };
  }

  static List<Map<String, dynamic>> demoVehicles() {
    return [
      {
        'vehicle_id': 'demo-vehicle-001',
        'vehicle_number': driverVehicleNumber,
        'vehicle_type': '4_wheeler',
        'brand': 'Hyundai',
        'model': 'i20',
        'color': 'White',
      },
      {
        'vehicle_id': 'demo-vehicle-002',
        'vehicle_number': 'KA 01 TK 1907',
        'vehicle_type': '2_wheeler',
        'brand': 'Ather',
        'model': '450X',
        'color': 'Grey',
      },
    ];
  }

  static Map<String, dynamic> demoDriverProfile() {
    return {
      'vehicle_id': 'demo-vehicle-001',
      'vehicle_number': driverVehicleNumber,
      'daily_seat_limit': 3,
    };
  }

  static List<Map<String, dynamic>> demoOpenRides() {
    return [
      {
        'ride_id': liveRideId,
        'start_location': {
          'latitude': riderPickupLatLng.latitude,
          'longitude': riderPickupLatLng.longitude,
        },
        'end_location': {
          'latitude': riderDestinationLatLng.latitude,
          'longitude': riderDestinationLatLng.longitude,
        },
        'start_address': riderPickupLabel,
        'end_address': riderDestinationLabel,
        'ride_date': '2026-03-20',
        'ride_time': '09:00:00',
        'available_seats': 2,
        'estimated_fare': 92,
        'allowed_gender': 'any',
      },
      {
        'ride_id': 'demo-ride-002',
        'start_location': {'latitude': 12.9208, 'longitude': 77.6049},
        'end_location': {
          'latitude': riderDestinationLatLng.latitude,
          'longitude': riderDestinationLatLng.longitude,
        },
        'start_address': 'Madiwala Check Post, Bangalore',
        'end_address': riderDestinationLabel,
        'ride_date': '2026-03-20',
        'ride_time': '08:45:00',
        'available_seats': 1,
        'estimated_fare': 88,
        'allowed_gender': 'female',
      },
      {
        'ride_id': 'demo-ride-003',
        'start_location': {'latitude': 12.9128, 'longitude': 77.5970},
        'end_location': {
          'latitude': riderDestinationLatLng.latitude,
          'longitude': riderDestinationLatLng.longitude,
        },
        'start_address': 'Jayanagar 4th Block, Bangalore',
        'end_address': riderDestinationLabel,
        'ride_date': '2026-03-20',
        'ride_time': '09:15:00',
        'available_seats': 3,
        'estimated_fare': 96,
        'allowed_gender': 'any',
      },
    ];
  }

  static List<Map<String, dynamic>> demoDriverRides() {
    return [
      {
        'ride_id': liveRideId,
        'start_address': driverPickupLabel,
        'end_address': riderDestinationLabel,
        'ride_date': '2026-03-20',
        'ride_time': '08:50:00',
        'status': 'open',
        'available_seats': 2,
        'estimated_fare': 84,
      },
      {
        'ride_id': 'demo-driver-ride-002',
        'start_address': 'Koramangala 5th Block, Bangalore',
        'end_address': riderDestinationLabel,
        'ride_date': '2026-03-19',
        'ride_time': '18:20:00',
        'status': 'completed',
        'available_seats': 0,
        'estimated_fare': 104,
      },
    ];
  }

  static List<Map<String, dynamic>> demoRideRequests() {
    return [
      {
        'request_id': 'demo-request-001',
        'user_id': 'demo-rider-201',
        'full_name': 'Nivedita Rao',
        'gender': 'female',
        'community': 'MBA',
        'pickup_address': 'Silk Board Junction, Bangalore',
        'pickup_lat': 12.9173,
        'pickup_lng': 77.6238,
        'status': 'pending',
      },
      {
        'request_id': 'demo-request-002',
        'user_id': 'demo-rider-202',
        'full_name': 'Rahul Menon',
        'gender': 'male',
        'community': 'BCom',
        'pickup_address': 'SG Palya Bus Stop, Bangalore',
        'pickup_lat': 12.9332,
        'pickup_lng': 77.6131,
        'status': 'pending',
      },
    ];
  }

  static List<Map<String, dynamic>> demoParticipants() {
    return [
      {
        'participant_id': 'demo-participant-001',
        'user_id': 'demo-rider-111',
        'full_name': 'Ananya Joseph',
        'pickup_address': 'Tavarekere Main Road, Bangalore',
        'pickup_lat': 12.9257,
        'pickup_lng': 77.6094,
        'is_picked_up': false,
        'pickup_otp': '4821',
      },
    ];
  }

  static List<Map<String, dynamic>> demoRideHistory() {
    return [
      {
        'ride_id': liveRideId,
        'history_state': 'active',
        'status_label': 'DRIVER ARRIVING',
        'user_role': 'passenger',
        'driver_id': driverUserId,
        'driver_name': driverName,
        'start_address': riderPickupLabel,
        'end_address': riderDestinationLabel,
        'estimated_fare': 92,
        'available_seats': 2,
        'ride_date': '2026-03-20',
        'ride_time': '09:00 AM',
        'vehicle_number': driverVehicleNumber,
      },
      {
        'ride_id': 'demo-history-requested-001',
        'history_state': 'requested',
        'status_label': 'REQUEST PENDING',
        'request_status': 'pending',
        'user_role': 'requester',
        'driver_id': 'demo-driver-002',
        'driver_name': 'Maya George',
        'start_address': 'HSR Layout Sector 2, Bangalore',
        'end_address': 'Christ University - Kengeri Campus',
        'estimated_fare': 118,
        'available_seats': 1,
        'ride_date': '2026-03-22',
        'ride_time': '07:45 AM',
        'vehicle_number': 'KA 03 HU 2209',
      },
      {
        'ride_id': 'demo-history-completed-001',
        'history_state': 'completed',
        'status_label': 'COMPLETED',
        'user_role': 'passenger',
        'driver_id': driverUserId,
        'driver_name': driverName,
        'start_address': 'Jayanagar Metro Station, Bangalore',
        'end_address': riderDestinationLabel,
        'estimated_fare': 86,
        'available_seats': 0,
        'ride_date': '2026-03-17',
        'ride_time': '08:30 AM',
        'vehicle_number': driverVehicleNumber,
      },
      {
        'ride_id': 'demo-history-cancelled-001',
        'history_state': 'cancelled',
        'status_label': 'CANCELLED',
        'user_role': 'driver',
        'driver_id': currentUserId,
        'driver_name': 'Demo Student',
        'start_address': 'JP Nagar 4th Phase, Bangalore',
        'end_address': riderDestinationLabel,
        'estimated_fare': 94,
        'available_seats': 3,
        'ride_date': '2026-03-15',
        'ride_time': '06:45 PM',
        'vehicle_number': driverVehicleNumber,
      },
    ];
  }

  static Map<String, List<Map<String, dynamic>>> demoRatingsByRide() {
    return {
      'demo-history-completed-001': [
        {
          'rater_id': 'demo-rider-555',
          'rated_user_id': driverUserId,
          'rating_value': 5,
        },
      ],
    };
  }

  static Map<String, dynamic> demoIdentityStatus() {
    return {'status': 'approved'};
  }

  static Map<String, dynamic> demoDriverVerificationStatus() {
    return {'status': 'approved'};
  }

  static List<Map<String, dynamic>> demoEmergencyContacts() {
    return [
      {
        'contact_id': 'demo-contact-001',
        'contact_name': 'Asha Nair',
        'contact_phone': '+91 99887 76655',
        'relationship': 'Mother',
      },
      {
        'contact_id': 'demo-contact-002',
        'contact_name': 'Joel Thomas',
        'contact_phone': '+91 98865 44321',
        'relationship': 'Flatmate',
      },
    ];
  }

  static List<Map<String, dynamic>> demoSosAlerts() {
    return [
      {
        'alert_id': 'demo-sos-001',
        'ride_id': 'demo-history-completed-001',
        'triggered_at': '2026-03-13T18:45:00Z',
      },
    ];
  }

  static List<Map<String, dynamic>> demoReports() {
    return [
      {
        'report_id': 'demo-report-001',
        'ride_id': 'demo-history-cancelled-001',
        'comment': 'Driver arrived late and route changed without notice.',
        'created_at': '2026-03-15T12:30:00Z',
      },
    ];
  }

  static Map<String, dynamic> buildCreatedDemoRide({
    required String pickupAddress,
    required String destinationAddress,
    required String rideDate,
    required String rideTime,
    required int availableSeats,
    required double? estimatedFare,
  }) {
    return {
      'ride_id': 'demo-created-${DateTime.now().millisecondsSinceEpoch}',
      'start_address': pickupAddress,
      'end_address': destinationAddress,
      'ride_date': rideDate,
      'ride_time': rideTime,
      'status': 'open',
      'available_seats': availableSeats,
      'estimated_fare': estimatedFare?.round() ?? 90,
    };
  }
}
