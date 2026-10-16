import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_rider/features/auth/domain/rider_model.dart';
import 'package:sheride_rider/core/constants/app_colors.dart';

void main() {
  group('SheRide Rider App - Phase 1 Unit Tests', () {
    test('RiderModel serialization and deserialization works correctly', () {
      final rider = RiderModel(
        uid: 'rider_uid_123',
        name: 'Relangi Durga',
        phone: '+919876543210',
        email: 'relangi.durga@example.com',
        gender: 'Female',
        vehicleType: 'TVS Jupiter (Scooter)',
        vehicleNumber: 'KA 05 AB 1234',
        emergencyContact: '+919876500000',
        documents: {'license': 'verified'},
        isOnline: false,
        isVerified: true,
        rating: 5.0,
        totalRides: 0,
        role: 'rider',
      );

      final map = rider.toMap();
      expect(map['uid'], 'rider_uid_123');
      expect(map['name'], 'Relangi Durga');
      expect(map['phone'], '+919876543210');
      expect(map['gender'], 'Female');
      expect(map['vehicleType'], 'TVS Jupiter (Scooter)');
      expect(map['vehicleNumber'], 'KA 05 AB 1234');
      expect(map['role'], 'rider');
      expect(map['isOnline'], false);
      expect(map['isVerified'], true);

      final reconstructed = RiderModel.fromMap(map);
      expect(reconstructed.uid, rider.uid);
      expect(reconstructed.name, rider.name);
      expect(reconstructed.phone, rider.phone);
      expect(reconstructed.vehicleNumber, rider.vehicleNumber);
      expect(reconstructed.role, 'rider');
    });

    test('Theme brand colors check in rider app', () {
      expect(AppColors.primary.toARGB32(), 0xFF7F00FD);
      expect(AppColors.secondary.toARGB32(), 0xFFFFB001);
      expect(AppColors.success.toARGB32(), 0xFF00C853);
    });

    test('Rider copyWith updates fields correctly', () {
      final rider = RiderModel(
        uid: 'rider_1',
        name: 'Initial Name',
        phone: '+911111111111',
        vehicleNumber: 'AP 05 BK 1111',
      );

      final updated = rider.copyWith(
        name: 'Updated Name',
        isOnline: true,
        totalRides: 10,
      );

      expect(updated.name, 'Updated Name');
      expect(updated.isOnline, true);
      expect(updated.totalRides, 10);
      expect(updated.vehicleNumber, 'AP 05 BK 1111');
    });
  });
}
