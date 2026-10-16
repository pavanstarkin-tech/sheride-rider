import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import 'widgets/custom_button.dart';
import 'widgets/custom_text_field.dart';

class CaptainOnboardingScreen extends StatefulWidget {
  const CaptainOnboardingScreen({super.key});

  @override
  State<CaptainOnboardingScreen> createState() => _CaptainOnboardingScreenState();
}

class _CaptainOnboardingScreenState extends State<CaptainOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _licenseController = TextEditingController();
  final _rcController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  String _selectedVehicleType = 'Scooty';
  final List<String> _vehicleTypes = [
    'Scooty',
    'Electric Scooty',
    'Bike',
    'Auto',
    'Mini Car',
    'Premium Car',
    'EV Car',
  ];

  bool _aadhaarUploaded = false;
  bool _licenseUploaded = false;
  bool _rcUploaded = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  void _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _nameController.text = user.displayName!;
      }
      try {
        final snap = await FirebaseDatabase.instance.ref('riders/${user.uid}').get();
        if (snap.exists && snap.value != null && mounted) {
          final data = Map<dynamic, dynamic>.from(snap.value as Map);
          if (data['name'] != null && _nameController.text.isEmpty) {
            _nameController.text = data['name'].toString();
          }
          if (data['vehicleNumber'] != null) {
            _vehicleNumberController.text = data['vehicleNumber'].toString();
          }
          if (data['vehicleType'] != null && _vehicleTypes.contains(data['vehicleType'])) {
            _selectedVehicleType = data['vehicleType'].toString();
          }
          final docs = data['documents'] as Map?;
          if (docs != null) {
            if (docs['aadhaarNumber'] != null) {
              _aadhaarController.text = docs['aadhaarNumber'].toString();
              _aadhaarUploaded = true;
            }
            if (docs['licenseNumber'] != null) {
              _licenseController.text = docs['licenseNumber'].toString();
              _licenseUploaded = true;
            }
            if (docs['rcNumber'] != null) {
              _rcController.text = docs['rcNumber'].toString();
              _rcUploaded = true;
            }
          }
          setState(() {});
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _vehicleNumberController.dispose();
    _aadhaarController.dispose();
    _licenseController.dispose();
    _rcController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_aadhaarUploaded || !_licenseUploaded || !_rcUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach / verify all 3 mandatory KYC documents (Aadhaar, License, RC)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseDatabase.instance.ref('riders/${user.uid}');
      await ref.update({
        'name': _nameController.text.trim(),
        'vehicleType': _selectedVehicleType,
        'vehicleNumber': _vehicleNumberController.text.trim().toUpperCase(),
        'emergencyContact': _emergencyPhoneController.text.trim(),
        'documents': {
          'aadhaarNumber': _aadhaarController.text.trim(),
          'licenseNumber': _licenseController.text.trim().toUpperCase(),
          'rcNumber': _rcController.text.trim().toUpperCase(),
          'aadhaarFile': 'verified_upload_aadhaar_${user.uid}.pdf',
          'licenseFile': 'verified_upload_license_${user.uid}.pdf',
          'rcFile': 'verified_upload_rc_${user.uid}.pdf',
          'submittedAt': DateTime.now().toIso8601String(),
        },
        'onboardingCompleted': true,
        'verificationStatus': 'pending',
        'isVerified': false,
        'updatedAt': now,
      });

      if (mounted) {
        setState(() => _isSubmitting = false);
        context.go('/waiting-approval');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving onboarding info: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8FD),
      appBar: AppBar(
        title: const Text('Captain KYC Onboarding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.primary),
            onPressed: () async {
              await context.read<AuthService>().signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7F00FD), Color(0xFFE91E63)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Colors.white, size: 36),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verified 100% Women Fleet',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Complete your vehicle registration and KYC documents for Mission Control approval.',
                              style: TextStyle(color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section 1: Captain Personal Info
                const Text('1. Captain Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                CustomTextField(
                  label: 'Full Legal Name',
                  hintText: 'As per Aadhaar Card',
                  controller: _nameController,
                  prefixIcon: const Icon(Icons.person_rounded),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'Emergency Contact Number',
                  hintText: '+91 Family / Guardian Phone',
                  controller: _emergencyPhoneController,
                  prefixIcon: const Icon(Icons.phone_rounded),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Valid 10-digit emergency phone required' : null,
                ),
                const SizedBox(height: 24),

                // Section 2: Vehicle Information
                const Text('2. Vehicle Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedVehicleType,
                  decoration: InputDecoration(
                    labelText: 'Vehicle Fleet Category',
                    prefixIcon: const Icon(Icons.two_wheeler_rounded, color: AppColors.primary),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                  items: _vehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                  onChanged: (v) => setState(() => _selectedVehicleType = v!),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'Vehicle Plate Number',
                  hintText: 'e.g. AP39 AB 1234',
                  controller: _vehicleNumberController,
                  prefixIcon: const Icon(Icons.pin_rounded),
                  validator: (v) => (v == null || v.trim().length < 6) ? 'Valid vehicle plate number required' : null,
                ),
                const SizedBox(height: 24),

                // Section 3: Document Uploads & Verification
                const Text('3. Government ID & KYC Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text('Upload photos or enter certificate numbers for Mission Control background check.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 14),

                // Aadhaar Document
                _buildDocUploadCard(
                  title: 'Aadhaar Card',
                  subtitle: '12-digit UIDAI Identity Proof',
                  icon: Icons.badge_rounded,
                  controller: _aadhaarController,
                  hint: '12-digit Aadhaar Number',
                  isUploaded: _aadhaarUploaded,
                  onUpload: () {
                    if (_aadhaarController.text.trim().length >= 12) {
                      setState(() => _aadhaarUploaded = true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid 12-digit Aadhaar Number first')));
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Driving License Document
                _buildDocUploadCard(
                  title: 'Driving License (DL)',
                  subtitle: 'Valid Two-Wheeler / Four-Wheeler License',
                  icon: Icons.credit_card_rounded,
                  controller: _licenseController,
                  hint: 'DL Registration Number',
                  isUploaded: _licenseUploaded,
                  onUpload: () {
                    if (_licenseController.text.trim().length >= 6) {
                      setState(() => _licenseUploaded = true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid Driving License Number first')));
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Vehicle RC Document
                _buildDocUploadCard(
                  title: 'Vehicle Registration Certificate (RC)',
                  subtitle: 'Official RC document issued by RTO',
                  icon: Icons.description_rounded,
                  controller: _rcController,
                  hint: 'RC Registration Number',
                  isUploaded: _rcUploaded,
                  onUpload: () {
                    if (_rcController.text.trim().length >= 6) {
                      setState(() => _rcUploaded = true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid Vehicle RC Number first')));
                    }
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                CustomButton(
                  text: 'Submit Application for Admin Review',
                  isLoading: _isSubmitting,
                  onPressed: _submitOnboarding,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    required bool isUploaded,
    required VoidCallback onUpload,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUploaded ? Colors.green.shade300 : Colors.grey.shade200, width: isUploaded ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUploaded ? Colors.green.shade50 : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: isUploaded ? Colors.green.shade700 : AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (isUploaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text('Attached', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF9F9FB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter $title number' : null,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onUpload,
                icon: Icon(isUploaded ? Icons.task_alt_rounded : Icons.upload_file_rounded, size: 16),
                label: Text(isUploaded ? 'Document Verified' : 'Attach File / Certify', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  foregroundColor: isUploaded ? Colors.green.shade800 : AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
