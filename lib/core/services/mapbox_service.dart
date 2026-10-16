import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../constants/api_constants.dart';
import '../../features/rides/domain/ride_model.dart';

class PlaceSearchResult {
  final String id;
  final String title;
  final String address;
  final double lat;
  final double lng;

  const PlaceSearchResult({
    required this.id,
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class MapboxService {
  static final MapboxService _instance = MapboxService._internal();
  factory MapboxService() => _instance;
  MapboxService._internal();

  MapboxMap? mapboxMap;
  geo.Position? currentPosition;

  static void initMapbox() {
    try {
      MapboxOptions.setAccessToken(ApiConstants.mapboxAccessToken);
    } catch (e) {
      debugPrint("Mapbox token initialization notice: $e");
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p)/2 + 
          cos(lat1 * p) * cos(lat2 * p) * 
          (1 - cos((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  List<LocationPoint> generateRoutePoints(LocationPoint start, LocationPoint end, {int steps = 12}) {
    final points = <LocationPoint>[start];
    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      final lat = start.lat + (end.lat - start.lat) * t + (sin(t * pi) * 0.002);
      final lng = start.lng + (end.lng - start.lng) * t;
      points.add(LocationPoint(lat: lat, lng: lng, address: ''));
    }
    points.add(end);
    return points;
  }
}
