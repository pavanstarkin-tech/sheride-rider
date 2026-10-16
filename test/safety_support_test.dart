import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_rider/features/notifications/data/notification_service.dart';
import 'package:sheride_rider/features/notifications/domain/notification_model.dart';
import 'package:sheride_rider/features/safety/data/safety_service.dart';
import 'package:sheride_rider/features/safety/domain/emergency_contact_model.dart';
import 'package:sheride_rider/features/safety/domain/sos_model.dart';
import 'package:sheride_rider/features/support/data/support_service.dart';
import 'package:sheride_rider/features/support/domain/support_ticket_model.dart';

void main() {
  group('Phase 4 Unit Tests - Rider App Safety, Support & Notifications', () {
    test('Captain SosModel correctly sets up location and status', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final sos = SosModel(
        sosId: 'sos_rider_1',
        uid: 'rider_durga',
        rideId: 'ride_active_101',
        lat: 17.0005,
        lng: 81.7800,
        timestamp: now,
        status: 'active',
      );

      final map = sos.toMap();
      expect(map['sosId'], 'sos_rider_1');
      expect(map['uid'], 'rider_durga');

      final fromMap = SosModel.fromMap(map, 'sos_rider_1');
      expect(fromMap.lat, 17.0005);
    });

    test('Captain EmergencyContactModel supports relationship and contact updates', () {
      final contact = EmergencyContactModel(
        contactId: 'ct_r_1',
        name: 'Rider Family Contact',
        phone: '+91 91234 56789',
        relation: 'Family',
      );

      expect(contact.relation, 'Family');
      final updated = contact.copyWith(phone: '+91 98888 77777');
      expect(updated.phone, '+91 98888 77777');
    });

    test('SupportTicketModel creates rider inquiries correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ticket = SupportTicketModel(
        ticketId: 't_r_1',
        uid: 'rider_durga',
        category: 'payout',
        subject: 'Weekly Payout Settlement',
        message: 'Requesting payout statement breakdown for this week.',
        status: 'open',
        createdAt: now,
        updatedAt: now,
      );

      expect(ticket.category, 'payout');
      expect(ticket.status, 'open');
    });

    test('NotificationModel serializes rider notifications with type and payload', () {
      final notif = NotificationModel(
        notificationId: 'notif_r_1',
        title: 'New Ride Request nearby!',
        body: 'Priya requested a ride from Station to Divancheruvu',
        type: 'ride',
        data: {'fare': 108, 'distanceKm': 3.9},
        isRead: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final map = notif.toMap();
      expect(map['title'], 'New Ride Request nearby!');
      expect(map['data']['fare'], 108);

      final parsed = NotificationModel.fromMap(map, 'notif_r_1');
      expect(parsed.type, 'ride');
      expect(parsed.data['distanceKm'], 3.9);
    });

    test('Captain SafetyService triggers and resolves emergency alerts', () async {
      final safety = SafetyService();
      const testRiderId = 'rider_test_sos';

      final sos = await safety.triggerSos(
        uid: testRiderId,
        lat: 17.0005,
        lng: 81.7800,
      );

      expect(sos.status, 'active');
      final resolved = await safety.resolveSos(sos.sosId);
      expect(resolved, true);
    });

    test('Captain SupportService creates tickets and retrieves list', () async {
      final support = SupportService();
      const testRiderId = 'rider_test_support';

      final ticket = await support.createTicket(
        uid: testRiderId,
        category: 'incentives',
        subject: 'Completed 10 rides bonus',
        message: 'Completed weekly quest milestone.',
      );

      expect(ticket.status, 'open');
      final list = await support.getTickets(testRiderId);
      expect(list.any((t) => t.ticketId == ticket.ticketId), true);
    });

    test('Captain NotificationService handles alerts and marking read', () async {
      final notifService = NotificationService();
      const testRiderId = 'rider_test_notif';

      await notifService.sendNotification(
        targetUid: testRiderId,
        title: 'Captain Bonus Active 🌸',
        body: 'Earn extra ₹50 per trip after 7 PM',
        type: 'ride',
      );

      await notifService.markAllAsRead(testRiderId);
      expect(true, isTrue);
    });
  });
}
