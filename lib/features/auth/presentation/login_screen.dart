import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import 'widgets/custom_button.dart';
import 'widgets/custom_text_field.dart';
import 'widgets/she_ride_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final String _selectedCountryCode = '+91';
  bool _obscurePassword = true;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _quickFillCaptainDemo() {
    setState(() {
      _emailController.text = 'durga.relangi@sheride.app';
      _passwordController.text = 'SheRideTestPass@2026';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demo captain credentials filled! Tap "Sign In as Captain". 🌸'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handlePhoneLogin() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final fullPhoneNumber = '$_selectedCountryCode$phone';
    final authService = context.read<AuthService>();

    await authService.signInWithPhone(
      fullPhoneNumber,
      onCodeSent: (verificationId, resendToken) {
        context.push('/otp', extra: {
          'verificationId': verificationId,
          'phoneNumber': fullPhoneNumber,
          'resendToken': resendToken,
        });
      },
      onVerificationFailed: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      },
      onVerificationCompleted: (credential) {
        context.go('/home');
      },
    );
  }

  Future<void> _navigateBasedOnRiderStatus(String uid) async {
    try {
      final snap = await FirebaseDatabase.instance.ref('riders/$uid').get();
      if (!mounted) return;
      if (!snap.exists || snap.value == null) {
        context.go('/onboarding');
        return;
      }
      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final onboardingDone = data['onboardingCompleted'] == true || data['documents'] != null;
      final status = (data['verificationStatus'] ?? 'pending').toString();
      final isVerified = data['isVerified'] == true || status == 'approved';

      if (!onboardingDone) {
        context.go('/onboarding');
      } else if (!isVerified) {
        context.go('/waiting-approval');
      } else {
        context.go('/home');
      }
    } catch (_) {
      if (mounted) context.go('/waiting-approval');
    }
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    try {
      final cred = await authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted && cred?.user != null) {
        await _navigateBasedOnRiderStatus(cred!.user!.uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authService.errorMessage ?? e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final authService = context.read<AuthService>();
      final cred = await authService.signInWithGoogle();
      if (!mounted) return;
      if (cred != null && cred.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, Captain ${cred.user!.displayName ?? "Partner"}! 🌸'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        await _navigateBasedOnRiderStatus(cred.user!.uid);
      } else if (authService.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authService.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showForgotPasswordModal() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
            const SizedBox(height: 18),
            Text(
              'Reset Captain Password 🌸',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your registered captain email address to receive a secure password reset link.',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            CustomTextField(
              controller: resetEmailController,
              label: 'Captain Email Address',
              hintText: 'captain@example.com',
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Send Reset Link',
              onPressed: () async {
                final email = resetEmailController.text.trim();
                final authService = context.read<AuthService>();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final success = await authService.sendPasswordResetEmail(email);
                if (success) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Password reset link sent to $email! Please check your inbox.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(authService.errorMessage ?? 'Failed to send reset email'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPolicyBottomSheet(String title, String subtitle, List<Map<String, String>> sections) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF757575)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, index) {
                    final sec = sections[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sec['title'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sec['content'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF616161),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      'I Understand & Agree',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSafetyPolicyModal() {
    _showPolicyBottomSheet(
      'Captain Safety Policy',
      'Guaranteed Safe Rides for Women Drivers',
      [
        {
          'title': '1. Verified Women Passengers Only',
          'content': 'Every passenger profile is verified prior to booking. Captains will never receive trip requests from unverified accounts.'
        },
        {
          'title': '2. 24/7 Dedicated Emergency Dispatch SOS',
          'content': 'Direct one-tap connection to local emergency response and our dedicated 24/7 Safety Command Center.'
        },
        {
          'title': '3. Zero Penalty for Safety Cancellations',
          'content': 'If you feel uncomfortable or unsafe at any point before trip start, you may cancel without affecting your captain rating.'
        },
      ],
    );
  }

  void _showTermsModal() {
    _showPolicyBottomSheet(
      'Captain Terms & Conditions',
      'Partner Driver Guidelines & Code of Conduct',
      [
        {
          'title': '1. Valid Driving Credentials',
          'content': 'All captains must possess an active driving license, valid vehicle registration (RC), and active insurance.'
        },
        {
          'title': '2. Instant & Transparent Payouts',
          'content': 'Earnings are computed dynamically and can be withdrawn directly to your linked UPI or bank account.'
        },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      // Brand Banner Logo matching User App
                      const SheRideBannerLogo(width: 270),
                      const SizedBox(height: 18),
                      Text(
                        'Welcome Lady Captain',
                        style: GoogleFonts.fraunces(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF180D2B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '100% Verified Female Captains • Drive & Earn Safely',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tab Switcher between Email and Phone
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EEFD),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: AppColors.textSecondary,
                          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'Email Login'),
                            Tab(text: 'Mobile OTP'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tab Contents
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Email Login (with Quick Demo Fill)
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Captain Credentials',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF180D2B)),
                                      ),
                                      TextButton.icon(
                                        onPressed: _quickFillCaptainDemo,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7F00FD)),
                                        label: Text(
                                          'Quick Demo Fill',
                                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF7F00FD)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  CustomTextField(
                                    controller: _emailController,
                                    label: 'Captain Email Address',
                                    hintText: 'durga.relangi@sheride.app',
                                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary, size: 18),
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (val) {
                                      if (val == null || !val.contains('@')) return 'Please enter a valid email address';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  CustomTextField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    hintText: '••••••••',
                                    obscureText: _obscurePassword,
                                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 18),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        color: const Color(0xFF757575),
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() => _obscurePassword = !_obscurePassword);
                                      },
                                    ),
                                    validator: (val) {
                                      if (val == null || val.length < 6) return 'Password must be at least 6 characters';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _showForgotPasswordModal,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  CustomButton(
                                    text: 'Sign In as Captain',
                                    isLoading: authService.isLoading,
                                    onPressed: _handleEmailLogin,
                                  ),
                                ],
                              ),
                            ),

                            // Tab 2: Mobile Phone OTP Login
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Enter your registered captain mobile number',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9F9F9),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFEDDCFF), width: 1.2),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                                          const SizedBox(width: 4),
                                          Text(
                                            _selectedCountryCode,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        maxLength: 10,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                        decoration: InputDecoration(
                                          counterText: '',
                                          hintText: '98765 43210',
                                          prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primary, size: 18),
                                          filled: true,
                                          fillColor: const Color(0xFFF9F9F9),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: const BorderSide(color: Color(0xFFEDDCFF)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: const BorderSide(color: Color(0xFFEDDCFF)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                CustomButton(
                                  text: 'Send Verification OTP →',
                                  isLoading: authService.isLoading,
                                  onPressed: _handlePhoneLogin,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Divider OR
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Google Sign In Button with Google Logo
                      OutlinedButton.icon(
                        onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                        icon: _isGoogleLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : Image.asset(
                                'assets/icons/google_logo.png',
                                width: 22,
                                height: 22,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.g_mobiledata_rounded,
                                  size: 26,
                                  color: Colors.red,
                                ),
                              ),
                        label: Text(
                          _isGoogleLoading ? 'Connecting to Google...' : 'Continue with Google',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Bottom Clickable Policies
                      Column(
                        children: [
                          Text(
                            'By continuing, you agree to Lady Pilot\'s',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              GestureDetector(
                                onTap: _showTermsModal,
                                child: Text(
                                  'Captain Terms & Conditions',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              Text('•', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF9E9E9E))),
                              GestureDetector(
                                onTap: _showSafetyPolicyModal,
                                child: Text(
                                  'Safety Policy',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
