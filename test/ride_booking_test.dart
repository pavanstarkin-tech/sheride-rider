import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_rider/features/rides/domain/ride_model.dart';
import 'package:sheride_rider/features/rides/data/ride_service.dart';

void main() {
  group('Phase 2 Unit Tests - Rider App Booking & Matching', () {
    test('ActiveRideRequest model parsing', () {
      final map = {
        'userId': 'user_priya',
        'vehicleType': 'bike',
        'pickupLat': 17.0005,
        'pickupLng': 81.7800,
        'pickupAddress': 'Rajahmundry Station',
        'dropAddress': 'Divancheruvu Hub',
        'fare': 108.0,
        'distanceKm': 3.9,
        'createdAt': 123456789,
      };

      final req = ActiveRideRequest.fromMap(map, 'ride_999');
      expect(req.rideId, 'ride_999');
      expect(req.userId, 'user_priya');
      expect(req.fare, 108.0);
      expect(req.distanceKm, 3.9);
      expect(req.pickupAddress, 'Rajahmundry Station');
    });

    test('Rider status transitions: requested -> accepted -> arrived -> started -> completed', () {
      final ride = RideModel(
        rideId: 'ride_202',
        userId: 'user_priya',
        status: 'requested',
        pickup: const LocationPoint(lat: 17.0, lng: 81.7, address: 'Pickup A'),
        drop: const LocationPoint(lat: 17.1, lng: 81.8, address: 'Drop B'),
        vehicleType: 'bike',
        fare: 108,
        distanceKm: 3.9,
        durationMin: 12,
        otp: '4829',
      );

      final accepted = ride.copyWith(
        status: 'accepted',
        riderId: 'rider_durga',
        acceptedAt: 1000,
      );
      expect(accepted.status, 'accepted');
      expect(accepted.riderId, 'rider_durga');

      final arrived = accepted.copyWith(status: 'arrived');
      expect(arrived.status, 'arrived');

      final started = arrived.copyWith(status: 'started', startedAt: 2000);
      expect(started.status, 'started');

      final completed = started.copyWith(status: 'completed', completedAt: 3000);
      expect(completed.status, 'completed');
    });
  });
}
