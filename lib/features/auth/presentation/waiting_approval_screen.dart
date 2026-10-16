import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import 'widgets/custom_button.dart';
import 'widgets/she_ride_logo.dart';

class WaitingApprovalScreen extends StatefulWidget {
  const WaitingApprovalScreen({super.key});

  @override
  State<WaitingApprovalScreen> createState() => _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState extends State<WaitingApprovalScreen> {
  StreamSubscription? _riderSub;
  String _status = 'pending';
  String _riderName = 'Lady Captain';
  String _vehicleNumber = '';
  String _vehicleType = 'Scooty';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startListeningToApprovalStatus();
  }

  @override
  void dispose() {
    _riderSub?.cancel();
    super.dispose();
  }

  void _startListeningToApprovalStatus() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return;
    }

    _riderSub = FirebaseDatabase.instance.ref('riders/$uid').onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final status = (data['verificationStatus'] ?? 'pending').toString();
        final verified = data['isVerified'] == true || status == 'approved';
        final name = (data['name'] ?? 'Lady Captain').toString();
        final vNum = (data['vehicleNumber'] ?? '').toString();
        final vType = (data['vehicleType'] ?? 'Scooty').toString();

        setState(() {
          _status = status;
          _riderName = name;
          _vehicleNumber = vNum;
          _vehicleType = vType;
          _isLoading = false;
        });

        // Real-time Unlock: If approved by Admin, instantly navigate to Dashboard!
        if (verified && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Congratulations! Your Captain account has been approved by SheRide Admin!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) context.go('/home');
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _handleSignOut() async {
    await context.read<AuthService>().signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const SheRideLogo(size: 32),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.primary),
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    // Animated Status Badge
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: _status == 'rejected'
                            ? Colors.red.shade50
                            : AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _status == 'rejected' ? Colors.red : AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          _status == 'rejected'
                              ? Icons.cancel_outlined
                              : Icons.hourglass_top_rounded,
                          size: 44,
                          color: _status == 'rejected' ? Colors.red : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      _status == 'rejected'
                          ? 'Verification Action Needed'
                          : 'Application Under Admin Review',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      _status == 'rejected'
                          ? 'Your document verification was rejected by SheRide Mission Control. Please update your details.'
                          : 'Welcome $_riderName! Your application and vehicle documents are currently being verified by SheRide Admin Mission Control. Once approved, your Captain dashboard will unlock automatically.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Captain & Vehicle Summary Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.two_wheeler_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _riderName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Text(
                                      '$_vehicleType • ${_vehicleNumber.isNotEmpty ? _vehicleNumber : "Number Pending"}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _status == 'rejected' ? Colors.red.shade50 : Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _status == 'rejected' ? Colors.red.shade200 : Colors.amber.shade300,
                                  ),
                                ),
                                child: Text(
                                  _status == 'rejected' ? 'REJECTED' : 'PENDING APPROVAL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _status == 'rejected' ? Colors.red.shade800 : Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Onboarding Verification Steps Timeline
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Onboarding Progress',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 16),
                          _buildTimelineStep(
                            icon: Icons.check_circle_rounded,
                            iconColor: Colors.green,
                            title: 'Step 1: Account Created',
                            subtitle: 'Phone & Profile registration successful',
                            isDone: true,
                          ),
                          _buildTimelineStep(
                            icon: Icons.check_circle_rounded,
                            iconColor: Colors.green,
                            title: 'Step 2: Onboarding Documents Uploaded',
                            subtitle: 'Aadhaar, Driving License & Vehicle RC registered',
                            isDone: true,
                          ),
                          _buildTimelineStep(
                            icon: _status == 'rejected'
                                ? Icons.cancel_rounded
                                : Icons.radio_button_checked_rounded,
                            iconColor: _status == 'rejected' ? Colors.red : Colors.orange,
                            title: 'Step 3: Admin KYC Verification',
                            subtitle: _status == 'rejected'
                                ? 'Admin marked application as rejected'
                                : 'SheRide Operations team review in progress',
                            isDone: false,
                            isCurrent: true,
                          ),
                          _buildTimelineStep(
                            icon: Icons.lock_outline_rounded,
                            iconColor: Colors.grey,
                            title: 'Step 4: Fleet Dashboard Activation',
                            subtitle: 'Unlocks automatically upon Admin approval',
                            isDone: false,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Action Buttons
                    if (_status == 'rejected')
                      CustomButton(
                        text: 'Update KYC Documents',
                        onPressed: () => context.push('/documents-kyc'),
                      )
                    else
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Listening for Admin approval in real-time...',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/documents-kyc'),
                            icon: const Icon(Icons.description_outlined, size: 18),
                            label: const Text('View / Edit Uploaded Documents'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _handleSignOut,
                      child: const Text('Log Out & Sign In with Another Account', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDone,
    bool isCurrent = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isDone ? Colors.green.shade200 : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isCurrent || isDone ? FontWeight.bold : FontWeight.w500,
                    color: isCurrent
                        ? AppColors.textPrimary
                        : (isDone ? Colors.black87 : Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                if (!isLast) const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
