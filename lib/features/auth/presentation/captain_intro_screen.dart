import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import 'widgets/she_ride_logo.dart';

class CaptainIntroScreen extends StatefulWidget {
  const CaptainIntroScreen({super.key});

  @override
  State<CaptainIntroScreen> createState() => _CaptainIntroScreenState();
}

class _CaptainIntroScreenState extends State<CaptainIntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Drive With Pride.\nEarn With Dignity.',
      'subtitle': "India's premier 100% verified female captain community. Drive on your own terms with absolute security.",
      'badge1': 'Female Riders Only',
      'badge1Icon': Icons.female_rounded,
      'badge2': 'Zero Surge Cuts',
      'badge2Icon': Icons.shield_rounded,
      'badge3': '24/7 Safety Command',
      'badge3Icon': Icons.headset_mic_rounded,
    },
    {
      'title': 'Keep 85% Payout.\nNo Hidden Fees.',
      'subtitle': 'Enjoy instant weekly payouts directly to your bank account. Transparent fares and performance quest bonuses.',
      'badge1': '85% Captain Share',
      'badge1Icon': Icons.account_balance_wallet_rounded,
      'badge2': 'Direct Bank Deposit',
      'badge2Icon': Icons.account_balance_rounded,
      'badge3': 'Weekly Statements',
      'badge3Icon': Icons.receipt_long_rounded,
    },
    {
      'title': 'Turn-by-Turn GPS.\nFloating Mini-Mode.',
      'subtitle': 'Seamless navigation with Google Maps picture-in-picture mini overlay, live OTP start verification, and instant SOS.',
      'badge1': 'Google Maps PiP',
      'badge1Icon': Icons.navigation_rounded,
      'badge2': 'Secure 4-Digit OTP',
      'badge2Icon': Icons.pin_rounded,
      'badge3': 'SOS Emergency Line',
      'badge3Icon': Icons.emergency_rounded,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Hero Visual
          Image.asset(
            'assets/images/welcome.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),

          // Rich Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.72),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.78),
                  Colors.black.withValues(alpha: 0.96),
                ],
                stops: const [0.0, 0.20, 0.44, 0.74, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Foreground Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SheRideBannerLogo(height: 44),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Drive & Earn Safely • 100% Verified Female Captains',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Interactive Swipeable Carousel
                  SizedBox(
                    height: 220,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (index) => setState(() => _currentPage = index),
                      itemBuilder: (context, index) {
                        final slide = _slides[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              slide['title'] as String,
                              style: GoogleFonts.fraunces(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              slide['subtitle'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFF6F6FE).withValues(alpha: 0.9),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Feature Badges
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSlideBadge(slide['badge1Icon'] as IconData, slide['badge1'] as String),
                                _buildSlideBadge(slide['badge2Icon'] as IconData, slide['badge2'] as String),
                                _buildSlideBadge(slide['badge3Icon'] as IconData, slide['badge3'] as String),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Carousel Page Indicators (Dots)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (idx) {
                      final isActive = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFFFB001) : Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 22),

                  // Primary CTA Golden Orange Pill Button: "Get Started as Captain →"
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB001),
                        foregroundColor: const Color(0xFF180D2B),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get Started as Captain',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF180D2B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20, color: Color(0xFF180D2B)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Already have account
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text(
                      'Already registered? Sign In',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideBadge(IconData icon, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
