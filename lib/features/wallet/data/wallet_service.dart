import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../domain/transaction_model.dart';
import '../domain/wallet_model.dart';

class WalletService {
  FirebaseDatabase? get _db {
    try {
      return FirebaseDatabase.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  String get currentUid => _auth?.currentUser?.uid ?? '';

  static final Map<String, double> _localBalances = {};
  static final List<TransactionModel> _localTransactions = [];

  Stream<WalletModel> streamWallet(String uid) {
    final db = _db;
    if (db == null) {
      final bal = _localBalances[uid] ?? 0.0;
      return Stream.value(
        WalletModel(uid: uid, balance: bal, currency: 'INR', updatedAt: DateTime.now().millisecondsSinceEpoch),
      );
    }

    return db.ref('wallets/$uid').onValue.map((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        return WalletModel.fromMap(data, uid);
      }
      return WalletModel(
        uid: uid,
        balance: _localBalances[uid] ?? 0.0,
        currency: 'INR',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  Future<WalletModel> getWallet(String uid) async {
    final db = _db;
    if (db == null) {
      final bal = _localBalances[uid] ?? 0.0;
      return WalletModel(uid: uid, balance: bal, currency: 'INR', updatedAt: DateTime.now().millisecondsSinceEpoch);
    }
    try {
      final snapshot = await db.ref('wallets/$uid').get();
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        return WalletModel.fromMap(data, uid);
      }
    } catch (_) {}
    return WalletModel(
      uid: uid,
      balance: _localBalances[uid] ?? 0.0,
      currency: 'INR',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<bool> creditRideEarnings(String riderId, double fare, String rideId) async {
    final earnings = fare * 0.85; // 85% net captain payout
    final db = _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final txId = 'tx_earn_$now';

    final transaction = TransactionModel(
      transactionId: txId,
      uid: riderId,
      type: 'credit',
      amount: earnings,
      rideId: rideId,
      description: 'Ride Earnings (85% of ₹${fare.toStringAsFixed(0)})',
      createdAt: now,
      status: 'success',
    );

    _localTransactions.insert(0, transaction);
    _localBalances[riderId] = (_localBalances[riderId] ?? 0.0) + earnings;

    if (db != null) {
      try {
        final walletRef = db.ref('wallets/$riderId');
        final currentSnap = await walletRef.get();
        double currentBal = 0.0;
        if (currentSnap.exists && currentSnap.value != null) {
          final data = Map<dynamic, dynamic>.from(currentSnap.value as Map);
          currentBal = (data['balance'] is num) ? (data['balance'] as num).toDouble() : 0.0;
        }
        final newBal = currentBal + earnings;
        await walletRef.set({
          'balance': newBal,
          'currency': 'INR',
          'updatedAt': now,
        });

        await db.ref('transactions/$txId').set(transaction.toMap());
        return true;
      } catch (e) {
        // Fallback
      }
    }
    return true;
  }

  Future<bool> withdrawEarnings(String riderId, double amount, {String bankAccount = 'UPI / Bank'}) async {
    final db = _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final txId = 'tx_wdr_$now';

    final transaction = TransactionModel(
      transactionId: txId,
      uid: riderId,
      type: 'debit',
      amount: amount,
      description: 'Bank Withdrawal to $bankAccount',
      createdAt: now,
      status: 'success',
    );

    _localTransactions.insert(0, transaction);
    _localBalances[riderId] = (_localBalances[riderId] ?? 0.0) - amount;

    if (db != null) {
      try {
        final walletRef = db.ref('wallets/$riderId');
        final currentSnap = await walletRef.get();
        double currentBal = 0.0;
        if (currentSnap.exists && currentSnap.value != null) {
          final data = Map<dynamic, dynamic>.from(currentSnap.value as Map);
          currentBal = (data['balance'] is num) ? (data['balance'] as num).toDouble() : 0.0;
        }
        final newBal = (currentBal - amount).clamp(0.0, double.infinity);
        await walletRef.set({
          'balance': newBal,
          'currency': 'INR',
          'updatedAt': now,
        });

        await db.ref('transactions/$txId').set(transaction.toMap());
        return true;
      } catch (e) {
        // Fallback
      }
    }
    return true;
  }

  Stream<List<TransactionModel>> streamTransactions(String uid) {
    final db = _db;
    if (db == null) {
      return Stream.value(_localTransactions.where((t) => t.uid == uid).toList());
    }

    return db.ref('transactions').orderByChild('uid').equalTo(uid).onValue.map((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final list = data.entries.map((e) {
          return TransactionModel.fromMap(Map<dynamic, dynamic>.from(e.value as Map), e.key.toString());
        }).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }
      return _localTransactions.where((t) => t.uid == uid).toList();
    });
  }
}
