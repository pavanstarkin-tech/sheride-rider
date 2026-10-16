import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/domain/rider_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  StreamSubscription? _riderProfileSub;
  StreamSubscription? _ridesSub;
  RiderModel? _riderProfile;
  bool _isLoading = true;
  int _totalRides = 0;
  double _rating = 5.0;

  @override
  void initState() {
    super.initState();
    _listenToRiderProfile();
  }

  @override
  void dispose() {
    _riderProfileSub?.cancel();
    _ridesSub?.cancel();
    super.dispose();
  }

  void _listenToRiderProfile() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    _riderProfileSub = FirebaseDatabase.instance.ref('riders/$uid').onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          _riderProfile = RiderModel.fromMap(data, uid: uid);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    });

    _ridesSub = FirebaseDatabase.instance.ref('rides').orderByChild('riderId').equalTo(uid).onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        int completed = 0;
        double ratingSum = 0;
        int ratingCount = 0;

        data.forEach((key, val) {
          if (val is Map && val['status'] == 'completed') {
            completed++;
            final r = val['passengerRating'];
            if (r is num && r > 0) {
              ratingSum += r.toDouble();
              ratingCount++;
            }
          }
        });

        setState(() {
          _totalRides = completed;
          _rating = ratingCount > 0 ? (ratingSum / ratingCount) : 5.0;
        });
      } else {
        setState(() {
          _totalRides = 0;
          _rating = 5.0;
        });
      }
    });
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to go offline and log out of SheRide Captain?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              await _authService.signOut();
              router.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final riderName = _riderProfile?.name.isNotEmpty == true
        ? _riderProfile!.name
        : (user?.displayName?.isNotEmpty == true ? user!.displayName! : 'Captain');
    final riderPhone = _riderProfile?.phone.isNotEmpty == true
        ? _riderProfile!.phone
        : (user?.phoneNumber?.isNotEmpty == true ? user!.phoneNumber! : (user?.email ?? 'No contact set'));
    final vehiclePlate = _riderProfile?.vehicleNumber.isNotEmpty == true
        ? _riderProfile!.vehicleNumber
        : 'Vehicle Pending';
    final vehicleType = _riderProfile?.vehicleType.isNotEmpty == true
        ? _riderProfile!.vehicleType
        : 'Scooty';
    final rating = _rating.toStringAsFixed(1);
    final totalRides = _totalRides;
    final dlNumber = _riderProfile?.documents['driving_license']?['number']?.toString();
    final displayDl = (dlNumber != null && dlNumber.isNotEmpty) ? dlNumber : 'Pending Upload';
    final isVerified = _riderProfile?.isVerified == true || _riderProfile?.verificationStatus == 'approved';
    final isBlocked = _riderProfile?.isBlocked == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Captain Profile', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            tooltip: 'Edit Profile',
            onPressed: () => context.push('/edit-profile', extra: _riderProfile),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Captain Hero Profile Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isBlocked
                              ? [const Color(0xFFE11D48), const Color(0xFFBE123C)]
                              : [const Color(0xFF7F00FD), const Color(0xFF5C00BC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      color: Colors.white.withValues(alpha: 0.2),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.two_wheeler_rounded, size: 36, color: Colors.white),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: isBlocked ? Colors.red : (isVerified ? Colors.green : Colors.amber),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isBlocked ? Icons.block : (isVerified ? Icons.verified : Icons.schedule),
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            riderName,
                                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => context.push('/edit-profile', extra: _riderProfile),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.edit, size: 12, color: Colors.white),
                                                SizedBox(width: 4),
                                                Text('Edit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$riderPhone • $vehiclePlate',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rounded, color: Color(0xFFFFD54F), size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$rating Rating • $totalRides Trips • $vehicleType',
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Document Verification & KYC Banner
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Document Verification & KYC',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        TextButton(
                          onPressed: () => context.push('/documents-kyc'),
                          child: const Text('Manage Docs →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => context.push('/documents-kyc'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildKycRow(Icons.badge_rounded, 'Driving License', displayDl, isVerified ? 'Approved' : 'Under Review', isVerified),
                            const Divider(height: 18),
                            _buildKycRow(Icons.electric_moped_rounded, 'Vehicle RC Book', vehiclePlate, isVerified ? 'Approved' : 'Under Review', isVerified),
                            const Divider(height: 18),
                            _buildKycRow(Icons.security_rounded, 'Police Verification', 'Women Safety Clearance', isVerified ? 'Approved' : 'Under Review', isVerified),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Captain Menu Items (All Sub-Pages Real & Functional)
                    const Text(
                      'Captain Management Hub',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildMenuItem(
                            Icons.card_giftcard_rounded,
                            'Incentives & Weekly Quests',
                            subtitle: 'Daily target bonuses & quest milestone rewards',
                            badge: 'ACTIVE BONUS',
                            onTap: () => context.push('/incentives-quests'),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            Icons.account_balance_wallet_outlined,
                            'Earnings & Payout Accounts',
                            subtitle: 'Instant transfer to bank account or UPI ID',
                            onTap: () => context.push('/earnings'),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            Icons.history_rounded,
                            'Ride & Trip History',
                            subtitle: 'Detailed receipts, passenger ratings & routes',
                            onTap: () => context.push('/ride-history'),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            Icons.notifications_none_rounded,
                            'Captain Notifications & Alerts',
                            subtitle: 'Ride requests and bonus announcements',
                            onTap: () => context.push('/notifications'),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            Icons.emergency_outlined,
                            'Captain SOS & Safety Hotline',
                            subtitle: '24/7 Police & SheRide Dispatch Desk',
                            badge: '24/7 ACTIVE',
                            onTap: () => context.push('/safety-hub'),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            Icons.settings_outlined,
                            'Captain Operational Settings',
                            subtitle: 'Auto-accept, voice navigation & language preferences',
                            onTap: () => context.push('/rider-settings'),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            Icons.support_agent_rounded,
                            'Captain Help & Support',
                            subtitle: 'Direct WhatsApp & Helpline desk',
                            onTap: () => context.push('/support'),
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            Icons.logout_rounded,
                            'Logout',
                            subtitle: 'Go offline and sign out',
                            iconColor: Colors.red.shade600,
                            titleColor: Colors.red.shade600,
                            onTap: _showLogoutConfirmDialog,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: GestureDetector(
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'SheRide Captain Partner',
                            applicationVersion: '1.0.0 (Build 1)',
                            applicationIcon: const Icon(Icons.two_wheeler_rounded, color: AppColors.primary, size: 36),
                            applicationLegalese: '© 2026 SheRide Technologies. 100% Women-Driven Fleet across India.',
                          );
                        },
                        child: Column(
                          children: [
                            Text(
                              'SheRide Captain Partner • v1.0.0 (Build 1) 🌸',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Empowering Women Drivers Across India • Tap for Info',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKycRow(IconData icon, String title, String docNum, String status, bool isApproved) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(docNum, style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.8))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isApproved ? Colors.green.shade50 : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isApproved ? Colors.green.shade200 : Colors.amber.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isApproved ? Icons.check_circle : Icons.schedule, color: isApproved ? Colors.green.shade700 : Colors.amber.shade800, size: 12),
              const SizedBox(width: 4),
              Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isApproved ? Colors.green.shade800 : Colors.amber.shade900)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    String? subtitle,
    String? badge,
    Color iconColor = AppColors.primary,
    Color titleColor = AppColors.textPrimary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: titleColor)),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
            ),
          ],
        ],
      ),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)) : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, endIndent: 16);
  }
}
