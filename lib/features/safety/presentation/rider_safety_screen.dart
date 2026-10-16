import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../data/safety_service.dart';

class RiderSafetyScreen extends StatefulWidget {
  const RiderSafetyScreen({super.key});

  @override
  State<RiderSafetyScreen> createState() => _RiderSafetyScreenState();
}

class _RiderSafetyScreenState extends State<RiderSafetyScreen> {
  final SafetyService _safetyService = SafetyService();

  void _triggerCaptainSos() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.emergencyRed, size: 28),
            SizedBox(width: 8),
            Text('CAPTAIN SOS', style: TextStyle(color: AppColors.emergencyRed, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Activate immediate emergency assistance? This alerts SheRide Emergency HQ & Nearest Police Dispatch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _safetyService.triggerSos(
                uid: _safetyService.currentUid,
                lat: 17.0005,
                lng: 81.7800,
                type: 'emergency',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚨 CAPTAIN SOS ACTIVATED - Dispatch Team Connected!'),
                    backgroundColor: AppColors.emergencyRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergencyRed, foregroundColor: Colors.white),
            child: const Text('TRIGGER SOS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Captain Safety Hub', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
              // SOS Button
              GestureDetector(
                onTap: _triggerCaptainSos,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(color: AppColors.emergencyRed.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sos_rounded, color: Colors.white, size: 36),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CAPTAIN EMERGENCY SOS',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            Text('Instant hotline to Police & SheRide HQ', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Safety Protocols & Features',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    _buildTile(Icons.verified_user_rounded, 'Verified Women-Only Passengers', 'All riders must complete female gender verification'),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildTile(Icons.pin_drop_rounded, 'Mandatory 4-Digit Ride PIN', 'Ride cannot start without the secret OTP from passenger'),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildTile(Icons.phone_in_talk_rounded, '24/7 Captain Safety Helpline', 'Direct toll-free access to SheRide Dispatch'),
                    const Divider(height: 1, indent: 56, endIndent: 16),
                    _buildTile(Icons.health_and_safety_rounded, 'Comprehensive Ride Insurance', 'Full insurance coverage during active rides'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    );
  }
}
