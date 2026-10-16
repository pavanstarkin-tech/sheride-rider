import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../../features/auth/domain/rider_model.dart';

class RealtimeDbService {
  final FirebaseDatabase _db;

  RealtimeDbService({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  DatabaseReference get _ridersRef => _db.ref(ApiConstants.nodeRiders);

  // Save Rider to /riders/{uid}
  Future<void> saveRiderData(RiderModel rider) async {
    try {
      await _ridersRef.child(rider.uid).set(rider.toMap());
      debugPrint("Rider data saved successfully to /riders/${rider.uid}");
    } catch (e) {
      debugPrint("RealtimeDbService saveRiderData error: $e");
      rethrow;
    }
  }

  // Get Rider from /riders/{uid}
  Future<RiderModel?> getRiderData(String uid) async {
    try {
      final snapshot = await _ridersRef.child(uid).get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        return RiderModel.fromMap(data, uid: uid);
      }
      return null;
    } catch (e) {
      debugPrint("RealtimeDbService getRiderData error: $e");
      return null;
    }
  }

  // Toggle Online / Offline Status
  Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    try {
      await _ridersRef.child(uid).update({
        'isOnline': isOnline,
        'lastActive': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("RealtimeDbService updateOnlineStatus error: $e");
    }
  }

  // Update Live Location
  Future<void> updateRiderLocation(String uid, double latitude, double longitude) async {
    try {
      await _ridersRef.child(uid).update({
        'location': {
          'lat': latitude,
          'lng': longitude,
          'updatedAt': DateTime.now().toIso8601String(),
        }
      });
    } catch (e) {
      debugPrint("RealtimeDbService updateRiderLocation error: $e");
    }
  }

  // Stream Rider Data
  Stream<RiderModel?> streamRiderData(String uid) {
    return _ridersRef.child(uid).onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        return RiderModel.fromMap(data, uid: uid);
      }
      return null;
    });
  }
}
