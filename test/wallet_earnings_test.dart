import 'package:flutter_test/flutter_test.dart';
import 'package:sheride_rider/features/rides/domain/rating_model.dart';
import 'package:sheride_rider/features/wallet/data/wallet_service.dart';
import 'package:sheride_rider/features/wallet/domain/transaction_model.dart';
import 'package:sheride_rider/features/wallet/domain/wallet_model.dart';

void main() {
  group('Phase 3 Unit Tests - Rider App', () {
    test('WalletModel stores and retrieves rider earnings balance', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final wallet = WalletModel(
        uid: 'rider_durga',
        balance: 2450.0,
        currency: 'INR',
        updatedAt: now,
      );

      final map = wallet.toMap();
      expect(map['uid'], 'rider_durga');
      expect(map['balance'], 2450.0);

      final parsed = WalletModel.fromMap(map, 'rider_durga');
      expect(parsed.balance, 2450.0);
    });

    test('TransactionModel correctly records captain earnings and withdrawals', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final tx = TransactionModel(
        transactionId: 'tx_r101',
        uid: 'rider_durga',
        type: 'credit',
        amount: 91.80, // 85% of 108
        rideId: 'ride_101',
        description: 'Ride Earnings (85% of ₹108)',
        createdAt: now,
        status: 'success',
      );

      final map = tx.toMap();
      expect(map['amount'], 91.80);
      expect(map['type'], 'credit');

      final parsed = TransactionModel.fromMap(map, 'tx_r101');
      expect(parsed.amount, 91.80);
      expect(parsed.description, contains('85%'));
    });

    test('RatingModel parses feedback and handles rating calculations', () {
      final rating = RatingModel(
        rideId: 'ride_101',
        fromUid: 'user_priya',
        toUid: 'rider_durga',
        rating: 5.0,
        feedback: 'Super fast and safe ride!',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      expect(rating.rating, 5.0);
      expect(rating.toUid, 'rider_durga');
      expect(rating.feedback, 'Super fast and safe ride!');
    });

    test('WalletService creditRideEarnings accurately computes 85% net captain payout', () async {
      final walletService = WalletService();
      const riderId = 'rider_test_payout';

      final initialWallet = await walletService.getWallet(riderId);
      final initialBal = initialWallet.balance;

      // Ride fare ₹100 -> Captain earns ₹85 (85%)
      await walletService.creditRideEarnings(riderId, 100.0, 'ride_test_100');

      final updatedWallet = await walletService.getWallet(riderId);
      expect(updatedWallet.balance, initialBal + 85.0);
    });

    test('WalletService withdrawEarnings debits the captain balance properly', () async {
      final walletService = WalletService();
      const riderId = 'rider_test_withdraw';

      await walletService.creditRideEarnings(riderId, 500.0, 'ride_500'); // +425 (85% of 500)
      final midWallet = await walletService.getWallet(riderId);

      await walletService.withdrawEarnings(riderId, 200.0, bankAccount: 'durga@upi');
      final finalWallet = await walletService.getWallet(riderId);

      expect(finalWallet.balance, midWallet.balance - 200.0);
    });
  });
}
