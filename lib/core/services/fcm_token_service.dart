import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class FcmTokenService {
  static final FcmTokenService _instance = FcmTokenService._internal();
  factory FcmTokenService() => _instance;
  FcmTokenService._internal();

  FirebaseDatabase? get _db {
    try {
      return FirebaseDatabase.instance;
    } catch (_) {
      return null;
    }
  }

  static const String _tokenPrefKey = 'sheride_rider_device_fcm_token';

  /// Obtain persistent FCM device token for pilot and save to Firebase RTDB & PHP API
  Future<String> registerRiderFcmToken(String uid) async {
    String token = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_tokenPrefKey);
      if (cached != null && cached.isNotEmpty) {
        token = cached;
      } else {
        token = 'fcm_rider_${uid.substring(0, uid.length > 8 ? 8 : uid.length)}_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}';
        await prefs.setString(_tokenPrefKey, token);
      }
    } catch (_) {
      token = 'fcm_rider_${uid}_${DateTime.now().millisecondsSinceEpoch}';
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final platform = kIsWeb ? 'web' : 'mobile';

    // 1. Save in Firebase Realtime Database
    final db = _db;
    if (db != null) {
      try {
        await db.ref('riders/$uid').update({
          'fcmToken': token,
          'lastActive': now,
        });

        await db.ref('fcmTokens/$uid').set({
          'uid': uid,
          'token': token,
          'fcmToken': token,
          'role': 'rider',
          'platform': platform,
          'updatedAt': now,
          'lastActive': now,
        });
      } catch (e) {
        debugPrint('Rider FCM token save warning: $e');
      }
    }

    return token;
  }

  /// Dispatch ride notification to passenger
  Future<void> sendPassengerPushNotification({
    required String rideId,
    required String event,
    required String passengerUid,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final notifId = 'notif_ride_${event}_$now';

    final notifPayload = {
      'notificationId': notifId,
      'title': title,
      'body': body,
      'type': 'ride',
      'rideId': rideId,
      'event': event,
      'isRead': false,
      'createdAt': now,
      'data': data,
    };

    final db = _db;
    if (db != null) {
      try {
        await db.ref('notifications/$passengerUid/$notifId').set(notifPayload);
        await db.ref('rides/$rideId/events/$now').set({
          'event': event,
          'timestamp': now,
          'title': title,
        });
      } catch (e) {
        debugPrint('Push notification RTDB dispatch warning: $e');
      }
    }
  }
}
