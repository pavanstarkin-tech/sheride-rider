import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/domain/rider_model.dart';

class EditRiderProfileScreen extends StatefulWidget {
  final RiderModel? initialProfile;

  const EditRiderProfileScreen({super.key, this.initialProfile});

  @override
  State<EditRiderProfileScreen> createState() => _EditRiderProfileScreenState();
}

class _EditRiderProfileScreenState extends State<EditRiderProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _vehicleNumberController;
  late TextEditingController _emergencyContactController;
  late String _selectedVehicleType;

  bool _isSaving = false;

  final List<String> _vehicleCategories = [
    'Scooty',
    'Electric Scooty',
    'Bike',
    'Priority Bike',
    'Auto',
    'Premium Auto',
    'Mini Cab',
    'Premium Cab',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    final currentUser = FirebaseAuth.instance.currentUser;

    _nameController = TextEditingController(text: p?.name ?? currentUser?.displayName ?? '');
    _phoneController = TextEditingController(text: p?.phone ?? currentUser?.phoneNumber ?? '');
    _emailController = TextEditingController(text: p?.email ?? currentUser?.email ?? '');
    _vehicleNumberController = TextEditingController(text: p?.vehicleNumber ?? 'AP 05 AB 1234');
    _emergencyContactController = TextEditingController(text: p?.emergencyContact ?? '+91 98765 43210');

    final existingType = p?.vehicleType ?? 'Scooty';
    _selectedVehicleType = _vehicleCategories.contains(existingType) ? existingType : 'Scooty';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _vehicleNumberController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No active user session.')),
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      final updatedData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'vehicleNumber': _vehicleNumberController.text.trim().toUpperCase(),
        'vehicleType': _selectedVehicleType,
        'emergencyContact': _emergencyContactController.text.trim(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      // 1. Update Firebase Realtime Database
      await FirebaseDatabase.instance.ref('riders/$uid').update(updatedData);

      // 2. Update Firebase Auth displayName
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null && _nameController.text.trim().isNotEmpty) {
        await authUser.updateDisplayName(_nameController.text.trim());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🌸 Captain Profile Updated Successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit Captain Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Info Badge
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your profile details are verified by Lady Pilot Mission Control to ensure 100% women passenger safety.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section: Personal Details
                const Text(
                  'Personal Information',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: _nameController,
                  label: 'Full Legal Name',
                  icon: Icons.person_outline_rounded,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _phoneController,
                  label: 'Registered Mobile Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid mobile number' : null,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),

                // Section: Vehicle Information
                const Text(
                  'Vehicle & Dispatch Details',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),

                // Vehicle Category Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedVehicleType,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                      items: _vehicleCategories.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Row(
                            children: [
                              const Icon(Icons.two_wheeler_rounded, size: 20, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Text(type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedVehicleType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _vehicleNumberController,
                  label: 'Vehicle Plate Number',
                  icon: Icons.numbers_rounded,
                  hint: 'AP 05 AB 1234',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter vehicle registration number' : null,
                ),
                const SizedBox(height: 24),

                // Section: Safety & Emergency
                const Text(
                  'Safety & Emergency Contact',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: _emergencyContactController,
                  label: 'Emergency Family Contact',
                  icon: Icons.contact_emergency_outlined,
                  keyboardType: TextInputType.phone,
                  hint: '+91 98765 43210',
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'Save Profile Changes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
