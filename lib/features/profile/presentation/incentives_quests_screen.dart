import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class IncentivesQuestsScreen extends StatefulWidget {
  const IncentivesQuestsScreen({super.key});

  @override
  State<IncentivesQuestsScreen> createState() => _IncentivesQuestsScreenState();
}

class _IncentivesQuestsScreenState extends State<IncentivesQuestsScreen> {
  int _completedRidesToday = 0;
  final int _targetRidesToday = 5;
  bool _dailyClaimed = false;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _fetchTodayProgress();
  }

  Future<void> _fetchTodayProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseDatabase.instance.ref('rides').orderByChild('riderId').equalTo(uid).get();
      if (snap.exists && snap.value != null) {
        final data = Map<dynamic, dynamic>.from(snap.value as Map);
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        final completedToday = data.values.where((v) {
          if (v is! Map) return false;
          final isComp = v['status'] == 'completed';
          final createdAt = (v['createdAt'] is num) ? (v['createdAt'] as num).toInt() : 0;
          return isComp && createdAt >= startOfToday;
        }).length;

        if (mounted) {
          setState(() {
            _completedRidesToday = completedToday;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _completedRidesToday = 0;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _claimReward(String questTitle, double amount) async {
    setState(() => _isClaiming = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isClaiming = false);
      return;
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final txId = 'bonus_${now}_${amount.toInt()}';

      // 1. Fetch current wallet balance
      final walletRef = FirebaseDatabase.instance.ref('wallets/$uid');
      final snap = await walletRef.get();
      double balance = 0.0;
      if (snap.exists && snap.value != null) {
        final data = Map<dynamic, dynamic>.from(snap.value as Map);
        balance = (data['balance'] is num) ? (data['balance'] as num).toDouble() : 0.0;
      }

      final newBalance = balance + amount;
      await walletRef.update({
        'balance': newBalance,
        'updatedAt': now,
      });

      // 2. Add transaction record
      await FirebaseDatabase.instance.ref('transactions/$txId').set({
        'transactionId': txId,
        'uid': uid,
        'type': 'quest_reward',
        'amount': amount,
        'description': 'Bonus Reward: $questTitle',
        'createdAt': now,
        'status': 'success',
      });

      // 3. Add in-app notification
      await FirebaseDatabase.instance.ref('notifications/$uid/notif_$txId').set({
        'notificationId': 'notif_$txId',
        'title': '🎉 Quest Bonus Credited!',
        'body': '₹${amount.toInt()} quest reward for "$questTitle" credited to your wallet balance.',
        'type': 'wallet',
        'isRead': false,
        'createdAt': now,
      });

      setState(() {
        _dailyClaimed = true;
        _isClaiming = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const Icon(Icons.celebration_rounded, color: Color(0xFFE91E63), size: 54),
                const SizedBox(height: 14),
                const Text(
                  '₹200 Bonus Credited! 🌸',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Congratulations! The incentive reward has been deposited directly into your captain earnings wallet. New balance: ₹${newBalance.toInt()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Great!'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error claiming bonus: $e')));
        setState(() => _isClaiming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyPercent = (_completedRidesToday / _targetRidesToday).clamp(0.0, 1.0);
    final canClaimDaily = _completedRidesToday >= _targetRidesToday && !_dailyClaimed;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Incentives & Quests', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F00FD), Color(0xFFE91E63)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF7F00FD).withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Weekly Quest Earnings',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                          child: const Text('ACTIVE CYCLE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('₹1,450 Potential Bonus', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD54F), size: 18),
                        SizedBox(width: 6),
                        Text('Gold Lady Pilot Tier • Guaranteed 88% Take-Home', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section: Daily Quests
              const Text(
                'Today\'s Milestone Quests',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),

              // Quest 1: 5 Rides Milestone
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: canClaimDaily ? const Color(0xFF10B981) : Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Complete 5 Trips Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF0EEFD), borderRadius: BorderRadius.circular(10)),
                          child: const Text('+₹200 Cash', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Complete 5 safe passenger rides in Rajahmundry city limits before midnight.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progress: $_completedRidesToday / $_targetRidesToday trips', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        Text('${(dailyPercent * 100).toInt()}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: dailyPercent,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF0EEFD),
                        valueColor: AlwaysStoppedAnimation<Color>(canClaimDaily ? const Color(0xFF10B981) : AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: canClaimDaily && !_isClaiming
                            ? () => _claimReward('Complete 5 Trips Today', 200)
                            : (_dailyClaimed ? null : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Complete 1 more ride to unlock this ₹200 bonus! 🌸')),
                                );
                              }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _dailyClaimed ? Colors.grey.shade300 : (canClaimDaily ? const Color(0xFF10B981) : AppColors.primary),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isClaiming
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                _dailyClaimed
                                    ? 'Claimed Already ✓'
                                    : (canClaimDaily ? 'Claim ₹200 Reward Now 🎉' : '1 Ride Remaining to Unlock'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Quest 2: Evening Peak Rush
              _buildQuestCard(
                title: 'Evening Peak Hour Rush (5 PM - 9 PM)',
                reward: '+₹150 Cash',
                description: 'Complete 3 trips during high passenger request hours today.',
                current: 2,
                target: 3,
              ),
              const SizedBox(height: 14),

              // Quest 3: Weekend Marathon
              _buildQuestCard(
                title: 'Weekend Lady Pilot Hero',
                reward: '+₹600 Cash',
                description: 'Complete 15 weekend trips to receive the highest partner bonus.',
                current: 7,
                target: 15,
              ),
              const SizedBox(height: 24),

              // Captain Tier Status
              const Text('Captain Partner Tiers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    _buildTierRow('🥈 Silver Pilot', '0 - 50 Rides', '15% Commission (Base)'),
                    const Divider(height: 20),
                    _buildTierRow('🥇 Gold Pilot (Active)', '50 - 200 Rides', '12% Commission (3% Rebate)', isCurrent: true),
                    const Divider(height: 20),
                    _buildTierRow('💎 Diamond Pilot', '200+ Rides', '10% Commission + Free EV Swap'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestCard({
    required String title,
    required String reward,
    required String description,
    required int current,
    required int target,
  }) {
    final pct = (current / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF0EEFD), borderRadius: BorderRadius.circular(10)),
                child: Text(reward, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress: $current / $target trips', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('${(pct * 100).toInt()}%', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFFF0EEFD),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierRow(String title, String subtitle, String perk, {bool isCurrent = false}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isCurrent ? AppColors.primary : AppColors.textPrimary)),
                  if (isCurrent) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: const Text('YOU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
        Text(perk, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCurrent ? const Color(0xFF059669) : Colors.grey.shade700)),
      ],
    );
  }
}
