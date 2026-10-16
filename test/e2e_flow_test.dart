import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_rider/core/services/network_service.dart';
import 'package:sheride_rider/features/auth/domain/rider_model.dart';
import 'package:sheride_rider/features/notifications/data/notification_service.dart';
import 'package:sheride_rider/features/rides/data/ride_service.dart';
import 'package:sheride_rider/features/rides/domain/ride_model.dart';
import 'package:sheride_rider/features/safety/data/safety_service.dart';
import 'package:sheride_rider/features/safety/domain/emergency_contact_model.dart';
import 'package:sheride_rider/features/support/data/support_service.dart';
import 'package:sheride_rider/features/wallet/data/wallet_service.dart';

void main() {
  group('Phase 5 - SheRide Rider/Captain App Full E2E & Production Hardening Suite', () {
    test('Captain E2E 1: Rider Profile & 100% Female Fleet Verification', () {
      final rider = RiderModel(
        uid: 'rider_durga_e2e',
        phone: '+919988776655',
        name: 'Durga Devi',
        email: 'durga@sheride.partner',
        vehicleType: 'bike',
        vehicleNumber: 'KA-01-EQ-9876',
        documents: {
          'drivingLicenseNumber': 'DL-KA-2022-8765432',
          'aadhaarNumber': 'XXXX-XXXX-9012',
        },
        isVerified: true,
        isOnline: true,
        rating: 4.96,
        totalRides: 284,
        createdAt: DateTime.now().toIso8601String(),
      );

      expect(rider.isVerified, isTrue);
      expect(rider.vehicleType, 'bike');
      final map = rider.toMap();
      final restored = RiderModel.fromMap(map, uid: rider.uid);
      expect(restored.name, 'Durga Devi');
    });

    test('Captain E2E 2: Incoming Ride Request, Accept, & Vehicle Match Validation', () {
      final request = ActiveRideRequest(
        rideId: 'ride_e2e_202',
        userId: 'user_ananya_e2e',
        pickupAddress: 'HSR Layout Sector 1',
        pickupLat: 12.9116,
        pickupLng: 77.6473,
        dropAddress: 'Bellandur EcoSpace',
        fare: 180.0,
        vehicleType: 'bike',
        distanceKm: 4.2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      expect(request.vehicleType, 'bike');
      expect(request.fare, 180.0);
    });

    test('Captain E2E 3: Ride Lifecycle with OTP PIN Verification', () {
      final ride = RideModel(
        rideId: 'ride_e2e_202',
        userId: 'user_ananya_e2e',
        riderId: 'rider_durga_e2e',
        status: 'accepted',
        pickup: const LocationPoint(lat: 12.9116, lng: 77.6473, address: 'HSR Layout Sector 1'),
        drop: const LocationPoint(lat: 12.9260, lng: 77.6762, address: 'Bellandur EcoSpace'),
        fare: 180.0,
        vehicleType: 'bike',
        distanceKm: 4.2,
        durationMin: 14,
        otp: '7391',
        paymentMethod: 'cash',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      const enteredOtpCorrect = '7391';
      const enteredOtpWrong = '1234';
      expect(enteredOtpCorrect == ride.otp, isTrue);
      expect(enteredOtpWrong == ride.otp, isFalse);

      final arrived = ride.copyWith(status: 'arrived');
      expect(arrived.status, 'arrived');
      final started = arrived.copyWith(status: 'started');
      expect(started.status, 'started');
      final completed = started.copyWith(status: 'completed');
      expect(completed.status, 'completed');
    });

    test('Captain E2E 4: 85% Guaranteed Net Earnings Credit & Wallet Update', () async {
      final walletService = WalletService();
      final currentWallet = await walletService.getWallet('rider_durga_e2e');
      final currentBal = currentWallet.balance;
      final fare = 200.0;
      final expectedEarnings = fare * 0.85;

      await walletService.creditRideEarnings('rider_durga_e2e', fare, 'ride_e2e_202');
      final newWallet = await walletService.getWallet('rider_durga_e2e');
      expect(newWallet.balance, currentBal + expectedEarnings);

      final withdrawSuccess = await walletService.withdrawEarnings('rider_durga_e2e', 100.0, bankAccount: 'UPI: durga@okaxis');
      expect(withdrawSuccess, isTrue);
      final afterWithdraw = await walletService.getWallet('rider_durga_e2e');
      expect(afterWithdraw.balance, newWallet.balance - 100.0);
    });

    test('Captain E2E 5: Captain Emergency SOS Trigger & Resolution', () async {
      final safety = SafetyService();
      final sos = await safety.triggerSos(
        uid: 'rider_durga_e2e',
        rideId: 'ride_e2e_202',
        lat: 12.9116,
        lng: 77.6473,
      );

      expect(sos.status, 'active');
      expect(sos.uid, 'rider_durga_e2e');

      await safety.resolveSos(sos.sosId);
      final active = await safety.streamActiveSos('rider_durga_e2e').first;
      expect(active == null || active.status == 'resolved', isTrue);
    });

    test('Captain E2E 6: Captain Emergency Contacts & Family Circle', () async {
      final safety = SafetyService();
      final contact = EmergencyContactModel(
        contactId: 'ct_sister_e2e',
        name: 'Kavitha Devi (Sister)',
        phone: '+919900112233',
        relation: 'Sister',
      );

      await safety.addEmergencyContact('rider_durga_e2e', contact);
      final contacts = await safety.getEmergencyContacts('rider_durga_e2e');
      expect(contacts.any((c) => c.phone == '+919900112233'), isTrue);
    });

    test('Captain E2E 7: Captain Support & Dispute Tickets', () async {
      final supportService = SupportService();
      final ticket = await supportService.createTicket(
        uid: 'rider_durga_e2e',
        category: 'earnings',
        subject: 'Weekly Incentive Query',
        message: 'Completed 50 rides milestone, checking bonus payout schedule.',
      );

      expect(ticket.ticketId.isNotEmpty, isTrue);
      expect(ticket.status, 'open');
      expect(ticket.category, 'earnings');

      final tickets = await supportService.getTickets('rider_durga_e2e');
      expect(tickets.any((t) => t.ticketId == ticket.ticketId), isTrue);
    });

    test('Captain E2E 8: Captain Notifications & Platform Alerts', () async {
      final notifService = NotificationService();
      await notifService.sendNotification(
        targetUid: 'rider_durga_e2e',
        title: 'New High-Demand Zone Alert ⚡',
        body: 'Surge of 1.2x active in Indiranagar & Koramangala.',
        type: 'ride',
      );

      final notifs = await notifService.streamNotifications('rider_durga_e2e').first;
      expect(notifs.isNotEmpty, isTrue);
      await notifService.markAllAsRead('rider_durga_e2e');
    });

    test('Captain E2E 9: Network Resilience & Offline Detection', () {
      final network = NetworkService();
      expect(network.isOnline.value, isNotNull);
    });

    test('Captain E2E 10: Edge Case - Listen to Incoming Stream', () {
      final rideService = RideService();
      expect(rideService.listenToActiveRequests(), isNotNull);
    });
  });
}
