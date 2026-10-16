import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/wallet_service.dart';
import '../domain/transaction_model.dart';
import '../domain/wallet_model.dart';
import '../../rides/data/ride_history_service.dart';
import '../../rides/domain/ride_model.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final WalletService _walletService = WalletService();

  void _showWithdrawDialog(double availableBalance) {
    final TextEditingController amountController = TextEditingController(text: availableBalance > 0 ? availableBalance.toInt().toString() : '');
    final TextEditingController upiController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Instant Captain Payout',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Transfer earnings directly to your bank account or UPI',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  labelText: 'Withdrawal Amount',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: upiController,
                decoration: InputDecoration(
                  labelText: 'UPI ID / Bank Account',
                  prefixIcon: const Icon(Icons.account_balance, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final entered = double.tryParse(amountController.text.trim()) ?? 0;
                    if (entered > 0 && entered <= availableBalance) {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      await _walletService.withdrawEarnings(
                        _walletService.currentUid,
                        entered,
                        bankAccount: upiController.text.trim(),
                      );
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('₹${entered.toStringAsFixed(0)} transferred to ${upiController.text.trim()}! 🌸'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                        setState(() {});
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount within your available balance')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Withdraw Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _walletService.currentUid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Captain Earnings', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Earnings Summary Card
              StreamBuilder<WalletModel>(
                stream: _walletService.streamWallet(uid),
                builder: (context, snapshot) {
                  final balance = snapshot.data?.balance ?? 0.0;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7F00FD), Color(0xFF5C00BC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7F00FD).withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Available for Payout',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Net 85% Payout', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '₹${balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showWithdrawDialog(balance),
                              icon: const Icon(Icons.account_balance_rounded, size: 18),
                              label: const Text('Withdraw Payout', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Weekly statements are sent to your registered email! 🌸')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white70),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Statements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Metrics Row - Computed from real completed rides
              StreamBuilder<List<RideModel>>(
                stream: RideHistoryService().streamRideHistory(uid),
                builder: (context, rideSnap) {
                  final rides = rideSnap.data ?? [];
                  final now = DateTime.now();
                  final startOfToday = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
                  final startOfWeek = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;

                  final completedRides = rides.where((r) => r.status == 'completed').toList();
                  final todayCompleted = completedRides.where((r) => r.createdAt >= startOfToday).toList();
                  final weekCompleted = completedRides.where((r) => r.createdAt >= startOfWeek).toList();

                  final todayEarnings = todayCompleted.fold<double>(0.0, (sum, r) => sum + (r.fare * 0.85));
                  final weekEarnings = weekCompleted.fold<double>(0.0, (sum, r) => sum + (r.fare * 0.85));
                  final totalEarnings = completedRides.fold<double>(0.0, (sum, r) => sum + (r.fare * 0.85));

                  return Row(
                    children: [
                      _buildMetricCard('Today', '₹${todayEarnings.toStringAsFixed(0)}', '${todayCompleted.length} Rides', Icons.trending_up_rounded),
                      const SizedBox(width: 10),
                      _buildMetricCard('This Week', '₹${weekEarnings.toStringAsFixed(0)}', '${weekCompleted.length} Rides', Icons.calendar_view_week_rounded),
                      const SizedBox(width: 10),
                      _buildMetricCard('All Time', '₹${totalEarnings.toStringAsFixed(0)}', '${completedRides.length} Trips', Icons.stars_rounded),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Commission Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Platform Fee Transparency',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You receive 85% of every ride fare. 15% covers safety fleet operations, 24/7 SOS monitoring & insurance.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recent Payouts List
              const Text(
                'Recent Earnings & Payouts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<TransactionModel>>(
                stream: _walletService.streamTransactions(uid),
                builder: (context, snapshot) {
                  final txs = snapshot.data ?? [];
                  if (txs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: const Center(child: Text('No transactions yet.', style: TextStyle(color: AppColors.textSecondary))),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: txs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final tx = txs[index];
                      final isCredit = tx.type == 'credit';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isCredit ? Colors.green.shade50 : Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCredit ? Icons.add_circle_outline : Icons.arrow_outward_rounded,
                                color: isCredit ? Colors.green.shade700 : Colors.blue.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.description,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateTime.fromMillisecondsSinceEpoch(tx.createdAt).toString().substring(0, 16),
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isCredit ? "+" : "-"}₹${tx.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isCredit ? Colors.green.shade700 : Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String mainVal, String subVal, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 8),
            Text(mainVal, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary.withValues(alpha: 0.8))),
            const SizedBox(height: 2),
            Text(subVal, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}
