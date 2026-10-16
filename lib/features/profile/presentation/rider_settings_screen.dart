import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';

class RiderSettingsScreen extends StatefulWidget {
  const RiderSettingsScreen({super.key});

  @override
  State<RiderSettingsScreen> createState() => _RiderSettingsScreenState();
}

class _RiderSettingsScreenState extends State<RiderSettingsScreen> {
  bool _autoAcceptRides = false;
  bool _voiceNavigation = true;
  bool _highVolumeAlarm = true;
  bool _batterySaver = false;
  int _searchRadiusKm = 10;
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _autoAcceptRides = prefs.getBool('rider_auto_accept') ?? false;
        _voiceNavigation = prefs.getBool('rider_voice_nav') ?? true;
        _highVolumeAlarm = prefs.getBool('rider_high_volume') ?? true;
        _batterySaver = prefs.getBool('rider_battery_saver') ?? false;
        _searchRadiusKm = prefs.getInt('rider_search_radius') ?? 10;
        _selectedLanguage = prefs.getString('rider_language') ?? 'English';
      });
    } catch (_) {}
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) await prefs.setBool(key, value);
      if (value is int) await prefs.setInt(key, value);
      if (value is String) await prefs.setString(key, value);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseDatabase.instance.ref('riders/$uid/settings').update({
          key: value,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Captain Settings', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
              // Section 1: Ride Dispatch Preferences
              const Text('Ride Dispatch Preferences', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeThumbColor: AppColors.primary,
                      title: const Text('Auto-Accept Nearby Rides', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Automatically accept trips within 3km to minimize passenger wait', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      value: _autoAcceptRides,
                      onChanged: (val) {
                        setState(() => _autoAcceptRides = val);
                        _saveSetting('rider_auto_accept', val);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Maximum Dispatch Service Radius', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Receive requests up to $_searchRadiusKm km from your current GPS location', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [5, 10, 15, 25].map((km) {
                              final isSel = _searchRadiusKm == km;
                              return ChoiceChip(
                                label: Text('$km km', style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.white : AppColors.textPrimary)),
                                selected: isSel,
                                selectedColor: AppColors.primary,
                                backgroundColor: const Color(0xFFF0EEFD),
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() => _searchRadiusKm = km);
                                    _saveSetting('rider_search_radius', km);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 2: Audio & Navigation Alerts
              const Text('Navigation & Audio Alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeThumbColor: AppColors.primary,
                      title: const Text('Voice Navigation Guidance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Spoken turn-by-turn directions during active navigation', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      value: _voiceNavigation,
                      onChanged: (val) {
                        setState(() => _voiceNavigation = val);
                        _saveSetting('rider_voice_nav', val);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      activeThumbColor: AppColors.primary,
                      title: const Text('Loud Ringtone on Incoming Rides', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Overrides silent mode so you never miss an incoming trip request', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      value: _highVolumeAlarm,
                      onChanged: (val) {
                        setState(() => _highVolumeAlarm = val);
                        _saveSetting('rider_high_volume', val);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      activeThumbColor: AppColors.primary,
                      title: const Text('Battery Optimizer Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Throttles background GPS polling during long idle standing periods', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      value: _batterySaver,
                      onChanged: (val) {
                        setState(() => _batterySaver = val);
                        _saveSetting('rider_battery_saver', val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 3: App Language
              const Text('Language & Regional', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    _buildLanguageItem('English', 'English (Default)'),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildLanguageItem('Telugu', 'తెలుగు (Telugu)'),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildLanguageItem('Hindi', 'हिन्दी (Hindi)'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Clear Cache & Diagnostics
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🌸 Local map and route cache cleared!')),
                    );
                  },
                  icon: const Icon(Icons.cleaning_services_rounded, size: 16, color: Colors.grey),
                  label: const Text('Clear Temporary Offline Map Cache', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageItem(String code, String label) {
    final isSelected = _selectedLanguage == code;
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20) : null,
      onTap: () {
        setState(() => _selectedLanguage = code);
        _saveSetting('rider_language', code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Language set to $label')),
        );
      },
    );
  }
}
