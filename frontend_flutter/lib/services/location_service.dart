import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for GPS location access, geocoding, and local address persistence.
class LocationService {
  // Legacy single-address keys retained for compatibility with older flows.
  static const String _savedAddressKey = 'savedPickupAddress';
  static const String _savedLatKey = 'savedPickupLat';
  static const String _savedLngKey = 'savedPickupLng';

  // New local saved-address store.
  static const String _savedAddressesKey = 'savedPickupAddressesV2';
  static const String _primarySavedAddressIdKey = 'primarySavedAddressId';

  /// Check and request location permissions, then return current position.
  /// Uses last known position as fast fallback, then fetches fresh GPS.
  static Future<LatLng> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        'Location services are disabled. Please enable GPS.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location permissions are permanently denied. Please enable them in Settings.',
      );
    }

    final lastKnown = await Geolocator.getLastKnownPosition();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      if (lastKnown != null) {
        return LatLng(lastKnown.latitude, lastKnown.longitude);
      }
      throw LocationException(
        'Could not determine your location. Please try again or enter an address manually.',
      );
    }
  }

  /// Stream live position updates. Useful for real-time ride tracking.
  static Stream<LatLng> getPositionStream({int distanceFilter = 10}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).map((pos) => LatLng(pos.latitude, pos.longitude));
  }

  /// Reverse geocode a [LatLng] to a human-readable address using Nominatim.
  static Future<String> reverseGeocode(LatLng position) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${position.latitude}&lon=${position.longitude}'
        '&format=json&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'UniRide-CarpoolApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] ?? 'Unknown location';
      }
    } catch (_) {}
    return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  /// Forward geocode an address string to a list of possible results.
  static Future<List<Map<String, dynamic>>> forwardGeocode(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=8&countrycodes=in'
        '&viewbox=74.0,18.5,78.5,11.5&bounded=0',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'UniRide-CarpoolApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data
            .map<Map<String, dynamic>>(
              (item) => {
                'displayName': item['display_name'] as String,
                'lat': double.parse(item['lat'] as String),
                'lng': double.parse(item['lon'] as String),
              },
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Checks whether a LatLng is roughly within India.
  static bool isInIndia(LatLng position) {
    return position.latitude >= 6.5 &&
        position.latitude <= 35.5 &&
        position.longitude >= 68.0 &&
        position.longitude <= 97.5;
  }

  // ---- Local Saved Address Persistence ----

  static Future<List<Map<String, dynamic>>> getSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedAddressesKey);

    if (raw == null || raw.isEmpty) {
      return _migrateLegacySavedAddress(prefs);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return _migrateLegacySavedAddress(prefs);

      final addresses = decoded
          .whereType<Map>()
          .map<Map<String, dynamic>>(
            (item) => Map<String, dynamic>.from(item.cast<String, dynamic>()),
          )
          .toList();
      await _ensurePrimaryAddress(prefs, addresses);
      return addresses;
    } catch (_) {
      return _migrateLegacySavedAddress(prefs);
    }
  }

  static Future<Map<String, dynamic>?> getSavedPickupAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final addresses = await getSavedAddresses();
    if (addresses.isEmpty) return null;

    final primaryId = prefs.getString(_primarySavedAddressIdKey);
    final primary = addresses.where((item) => item['id'] == primaryId).firstOrNull;
    final selected = primary ?? addresses.first;
    return {
      'id': selected['id'],
      'title': selected['title'],
      'type': selected['type'],
      'address': selected['address'],
      'lat': selected['lat'],
      'lng': selected['lng'],
    };
  }

  static Future<bool> hasSavedAddress() async {
    final addresses = await getSavedAddresses();
    return addresses.isNotEmpty;
  }

  static Future<void> savePickupAddress({
    required String address,
    required double lat,
    required double lng,
  }) async {
    final existingPrimary = await getSavedPickupAddress();
    await saveSavedAddress(
      id: existingPrimary?['id']?.toString(),
      title: existingPrimary?['title']?.toString() ?? 'Saved Place',
      address: address,
      lat: lat,
      lng: lng,
      type: existingPrimary?['type']?.toString() ?? 'other',
      makePrimary: true,
    );
  }

  static Future<void> saveSavedAddress({
    String? id,
    required String title,
    required String address,
    required double lat,
    required double lng,
    String type = 'other',
    bool makePrimary = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final addresses = await getSavedAddresses();
    final normalizedAddress = address.trim();
    final normalizedTitle = title.trim().isEmpty ? 'Saved Place' : title.trim();
    final addressId = id ?? _buildAddressId();

    final payload = <String, dynamic>{
      'id': addressId,
      'title': normalizedTitle,
      'address': normalizedAddress,
      'lat': lat,
      'lng': lng,
      'type': _normalizeAddressType(type),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final existingIndex = addresses.indexWhere((item) => item['id'] == addressId);
    if (existingIndex >= 0) {
      addresses[existingIndex] = payload;
    } else {
      final duplicateIndex = addresses.indexWhere(
        (item) =>
            item['address']?.toString().trim().toLowerCase() ==
            normalizedAddress.toLowerCase(),
      );
      if (duplicateIndex >= 0) {
        addresses[duplicateIndex] = {
          ...addresses[duplicateIndex],
          ...payload,
          'id': addresses[duplicateIndex]['id'],
        };
      } else {
        addresses.add(payload);
      }
    }

    await prefs.setString(_savedAddressesKey, jsonEncode(addresses));

    final savedId = existingIndex >= 0
        ? addressId
        : (() {
            final duplicate = addresses.where(
              (item) =>
                  item['address']?.toString().trim().toLowerCase() ==
                  normalizedAddress.toLowerCase(),
            );
            return duplicate.isNotEmpty
                ? duplicate.first['id'].toString()
                : addressId;
          })();

    if (makePrimary || prefs.getString(_primarySavedAddressIdKey) == null) {
      await prefs.setString(_primarySavedAddressIdKey, savedId);
    }

    await _syncLegacyPrimaryAddressCache(prefs, addresses);
  }

  static Future<void> deleteSavedAddress(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final addresses = await getSavedAddresses();
    addresses.removeWhere((item) => item['id'] == id);
    await prefs.setString(_savedAddressesKey, jsonEncode(addresses));

    final primaryId = prefs.getString(_primarySavedAddressIdKey);
    if (primaryId == id) {
      if (addresses.isEmpty) {
        await prefs.remove(_primarySavedAddressIdKey);
      } else {
        await prefs.setString(
          _primarySavedAddressIdKey,
          addresses.first['id'].toString(),
        );
      }
    }

    await _syncLegacyPrimaryAddressCache(prefs, addresses);
  }

  static Future<void> setPrimarySavedAddress(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final addresses = await getSavedAddresses();
    final exists = addresses.any((item) => item['id'] == id);
    if (!exists) return;
    await prefs.setString(_primarySavedAddressIdKey, id);
    await _syncLegacyPrimaryAddressCache(prefs, addresses);
  }

  static Future<List<Map<String, dynamic>>> _migrateLegacySavedAddress(
    SharedPreferences prefs,
  ) async {
    final legacyAddress = prefs.getString(_savedAddressKey);
    final legacyLat = prefs.getDouble(_savedLatKey);
    final legacyLng = prefs.getDouble(_savedLngKey);

    if (legacyAddress == null || legacyLat == null || legacyLng == null) {
      return [];
    }

    final migrated = [
      {
        'id': _buildAddressId(),
        'title': 'Saved Place',
        'address': legacyAddress,
        'lat': legacyLat,
        'lng': legacyLng,
        'type': 'other',
        'updated_at': DateTime.now().toIso8601String(),
      },
    ];

    await prefs.setString(_savedAddressesKey, jsonEncode(migrated));
    await prefs.setString(
      _primarySavedAddressIdKey,
      migrated.first['id'].toString(),
    );
    await _syncLegacyPrimaryAddressCache(prefs, migrated);
    return migrated;
  }

  static Future<void> _ensurePrimaryAddress(
    SharedPreferences prefs,
    List<Map<String, dynamic>> addresses,
  ) async {
    if (addresses.isEmpty) {
      await prefs.remove(_primarySavedAddressIdKey);
      await _syncLegacyPrimaryAddressCache(prefs, addresses);
      return;
    }

    final primaryId = prefs.getString(_primarySavedAddressIdKey);
    final exists = addresses.any((item) => item['id'] == primaryId);
    if (!exists) {
      await prefs.setString(
        _primarySavedAddressIdKey,
        addresses.first['id'].toString(),
      );
    }
    await _syncLegacyPrimaryAddressCache(prefs, addresses);
  }

  static Future<void> _syncLegacyPrimaryAddressCache(
    SharedPreferences prefs,
    List<Map<String, dynamic>> addresses,
  ) async {
    if (addresses.isEmpty) {
      await prefs.remove(_savedAddressKey);
      await prefs.remove(_savedLatKey);
      await prefs.remove(_savedLngKey);
      return;
    }

    final primaryId = prefs.getString(_primarySavedAddressIdKey);
    final primary = addresses.where((item) => item['id'] == primaryId).firstOrNull;
    final selected = primary ?? addresses.first;
    await prefs.setString(_savedAddressKey, selected['address'].toString());
    await prefs.setDouble(_savedLatKey, (selected['lat'] as num).toDouble());
    await prefs.setDouble(_savedLngKey, (selected['lng'] as num).toDouble());
  }

  static String _buildAddressId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  static String _normalizeAddressType(String type) {
    switch (type) {
      case 'home':
      case 'work':
      case 'other':
        return type;
      default:
        return 'other';
    }
  }
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
