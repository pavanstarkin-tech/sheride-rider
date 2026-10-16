import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../auth/presentation/widgets/she_ride_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final currentUser = context.read<AuthService>().currentUser;

    if (currentUser == null) {
      // Clear any dangling local tokens
      await StorageService().clearSession();
      if (mounted) context.go('/login');
      return;
    }

    // Check Captain's real-time onboarding and approval status in Firebase RTDB
    try {
      final snap = await FirebaseDatabase.instance.ref('riders/${currentUser.uid}').get();
      if (!snap.exists || snap.value == null) {
        if (mounted) context.go('/onboarding');
        return;
      }

      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final onboardingDone = data['onboardingCompleted'] == true || data['documents'] != null;
      final status = (data['verificationStatus'] ?? 'pending').toString();
      final isVerified = data['isVerified'] == true || status == 'approved';

      if (!onboardingDone) {
        if (mounted) context.go('/onboarding');
      } else if (!isVerified) {
        // Pending Admin KYC Approval -> strictly navigate to Waiting page!
        if (mounted) context.go('/waiting-approval');
      } else {
        // Fully approved by SheRide Admin -> proceed to Captain Dashboard!
        if (mounted) context.go('/home');
      }
    } catch (_) {
      if (mounted) context.go('/waiting-approval');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF0EEFD),
              Color(0xFFFFFFFF),
              Color(0xFFF0EEFD),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withValues(alpha: 0.25),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withValues(alpha: 0.2),
                ),
              ),
            ),

            // Logo
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: const SheRideLogo(size: 96),
              ),
            ),

            // Bottom Trust Badges
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPillBadge(Icons.woman_rounded, '100% Women Fleet'),
                      _buildPillBadge(Icons.payments_rounded, 'Instant Daily Payouts'),
                      _buildPillBadge(Icons.verified_user_rounded, 'Verified & Safe'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
