import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  StreamSubscription<Position>? _positionStreamSub;
  Position? _lastKnownPosition;

  Position? get lastKnownPosition => _lastKnownPosition;

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      _lastKnownPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return _lastKnownPosition;
    } catch (e) {
      debugPrint("Error getting rider position: $e");
      return null;
    }
  }

  // Publish rider location every 3-5 seconds when online
  void startRiderLocationPublishing(
    String riderId, {
    bool isOnline = true,
    String? currentRideId,
    String? vehicleType,
    String? riderName,
  }) {
    _positionStreamSub?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _lastKnownPosition = position;
        _db.ref('riderLocations/$riderId').update({
          'riderId': riderId,
          'lat': position.latitude,
          'latitude': position.latitude,
          'lng': position.longitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'updatedAt': ServerValue.timestamp,
          'isOnline': isOnline,
          'currentRideId': currentRideId,
          if (vehicleType != null) 'vehicleType': vehicleType,
          if (riderName != null) 'riderName': riderName,
        }).catchError((err) {
          debugPrint("riderLocations write notice: $err");
        });
      },
      onError: (err) {
        debugPrint("Rider location stream error: $err");
      },
    );
  }

  void updateOnlineStatus(String riderId, bool isOnline, {String? currentRideId}) {
    _db.ref('riderLocations/$riderId').update({
      'isOnline': isOnline,
      'currentRideId': currentRideId,
      'updatedAt': ServerValue.timestamp,
    }).catchError((err) => debugPrint("Status update notice: $err"));
  }

  void stopLocationPublishing() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
  }
}
