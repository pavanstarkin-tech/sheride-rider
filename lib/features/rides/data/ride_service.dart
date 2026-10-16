import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../domain/ride_model.dart';
import '../../auth/domain/rider_model.dart';

class ActiveRideRequest {
  final String rideId;
  final String userId;
  final String userName;
  final String userPhone;
  final String vehicleType;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double dropLat;
  final double dropLng;
  final String dropAddress;
  final double fare;
  final double distanceKm;
  final int durationMin;
  final String otp;
  final String paymentMethod;
  final int createdAt;

  const ActiveRideRequest({
    required this.rideId,
    required this.userId,
    this.userName = 'Passenger',
    this.userPhone = '',
    required this.vehicleType,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    this.dropLat = 17.0520,
    this.dropLng = 81.8210,
    required this.dropAddress,
    required this.fare,
    required this.distanceKm,
    this.durationMin = 15,
    this.otp = '1234',
    this.paymentMethod = 'cash',
    required this.createdAt,
  });

  factory ActiveRideRequest.fromMap(Map<dynamic, dynamic> map, String rideId) {
    return ActiveRideRequest(
      rideId: rideId,
      userId: (map['userId'] ?? '').toString(),
      userName: (map['userName'] ?? 'Passenger').toString(),
      userPhone: (map['userPhone'] ?? '').toString(),
      vehicleType: (map['vehicleType'] ?? 'scooty').toString(),
      pickupLat: (map['pickupLat'] is num) ? (map['pickupLat'] as num).toDouble() : 17.0005,
      pickupLng: (map['pickupLng'] is num) ? (map['pickupLng'] as num).toDouble() : 81.7800,
      pickupAddress: (map['pickupAddress'] ?? map['pickupName'] ?? 'Pickup Location').toString(),
      dropLat: (map['dropLat'] is num) ? (map['dropLat'] as num).toDouble() : 17.0520,
      dropLng: (map['dropLng'] is num) ? (map['dropLng'] as num).toDouble() : 81.8210,
      dropAddress: (map['dropAddress'] ?? map['dropName'] ?? 'Destination').toString(),
      fare: (map['fare'] is num) ? (map['fare'] as num).toDouble() : 50.0,
      distanceKm: (map['distanceKm'] is num) ? (map['distanceKm'] as num).toDouble() : 3.0,
      durationMin: (map['durationMin'] is num) ? (map['durationMin'] as num).toInt() : 15,
      otp: (map['otp'] ?? '1234').toString(),
      paymentMethod: (map['paymentMethod'] ?? 'cash').toString(),
      createdAt: (map['createdAt'] is num) ? (map['createdAt'] as num).toInt() : DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class RideService extends ChangeNotifier {
  FirebaseDatabase? _db;

  RideService({FirebaseDatabase? db}) : _db = db;

  FirebaseDatabase get db {
    if (_db == null) {
      try {
        _db = FirebaseDatabase.instance;
      } catch (e) {
        debugPrint("RideService DB fallback notice: $e");
      }
    }
    return _db ?? FirebaseDatabase.instance;
  }

  // 1. Listen to active incoming ride requests filtered strictly by Captain's location proximity & vehicle type
  Stream<List<ActiveRideRequest>> listenToActiveRequests({
    double? riderLat,
    double? riderLng,
    String? riderVehicleType,
    double maxRadiusKm = 15.0,
  }) {
    try {
      return db.ref('activeRequests').onValue.map((event) {
        final list = <ActiveRideRequest>[];
        if (event.snapshot.exists && event.snapshot.value != null) {
          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          data.forEach((key, val) {
            if (val is Map) {
              final req = ActiveRideRequest.fromMap(Map<dynamic, dynamic>.from(val), key.toString());

              // 1. Proximity check based on Captain's real-time live location
              bool isNearby = true;
              if (riderLat != null && riderLng != null && riderLat != 0.0 && riderLng != 0.0) {
                final dist = _calculateHaversineDistanceKm(riderLat, riderLng, req.pickupLat, req.pickupLng);
                if (dist > maxRadiusKm) {
                  isNearby = false;
                }
              }

              // 2. Vehicle category compatibility check
              bool isCompatibleVehicle = true;
              if (riderVehicleType != null && riderVehicleType.isNotEmpty) {
                final rType = riderVehicleType.toLowerCase();
                final vType = req.vehicleType.toLowerCase();
                if (rType.contains('scoot') || rType.contains('bike')) {
                  isCompatibleVehicle = vType.contains('scoot') || vType.contains('bike');
                } else if (rType.contains('auto')) {
                  isCompatibleVehicle = vType.contains('auto');
                } else if (rType.contains('car') || rType.contains('cab')) {
                  isCompatibleVehicle = vType.contains('car') || vType.contains('cab');
                }
              }

              if (isNearby && isCompatibleVehicle) {
                list.add(req);
              }
            }
          });
        }
        return list;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  static double _calculateHaversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  // 2. Accept Ride Request
  Future<RideModel?> acceptRide({
    required String rideId,
    required RiderModel rider,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      // 1. Update /rides/{rideId}
      await db.ref('rides/$rideId').update({
        'riderId': rider.uid,
        'status': 'accepted',
        'acceptedAt': timestamp,
        'riderName': rider.name,
        'riderPhone': rider.phone,
        'riderPhoto': rider.profileImageUrl,
        'vehicleNumber': rider.vehicleNumber,
        'riderRating': rider.rating,
      });

      // 2. Remove from activeRequests
      await db.ref('activeRequests/$rideId').remove();

      // 3. Update rider current ride
      await db.ref('riderLocations/${rider.uid}').update({
        'currentRideId': rideId,
      });

      debugPrint("Ride $rideId accepted by Rider ${rider.name}");

      // Fetch the full RideModel from /rides/{rideId}
      final snap = await db.ref('rides/$rideId').get();
      if (snap.exists && snap.value != null) {
        final data = Map<dynamic, dynamic>.from(snap.value as Map);
        return RideModel.fromMap(data, rideId: rideId);
      }
    } catch (e) {
      debugPrint("acceptRide notice: $e");
    }
    return null;
  }

  // 3. Stream Single Ride Status
  Stream<RideModel?> streamRide(String rideId) {
    try {
      return db.ref('rides/$rideId').onValue.map((event) {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          return RideModel.fromMap(data, rideId: rideId);
        }
        return null;
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  // 4. Update Ride Status (arrived, started, completed, cancelled)
  Future<void> updateRideStatus(
    String rideId,
    String status, {
    String? otp,
    String? riderId,
    String cancelledBy = 'rider',
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> updates = {
      'status': status,
    };

    if (status == 'arrived') {
      updates['arrivedAt'] = timestamp;
    } else if (status == 'started') {
      updates['startedAt'] = timestamp;
    } else if (status == 'completed') {
      updates['completedAt'] = timestamp;
      if (riderId != null) {
        await db.ref('riderLocations/$riderId').update({'currentRideId': null});
      }
    } else if (status == 'cancelled') {
      updates['cancelledAt'] = timestamp;
      updates['cancelledBy'] = cancelledBy;
      if (riderId != null) {
        await db.ref('riderLocations/$riderId').update({'currentRideId': null});
      }
      await db.ref('activeRequests/$rideId').remove();
    }

    try {
      await db.ref('rides/$rideId').update(updates);
    } catch (e) {
      debugPrint("updateRideStatus notice: $e");
    }
  }
}
