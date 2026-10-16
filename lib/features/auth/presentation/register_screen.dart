import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/realtime_db_service.dart';
import '../domain/rider_model.dart';
import 'widgets/custom_button.dart';
import 'widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  final String uid;
  final String phone;

  const RegisterScreen({
    super.key,
    required this.uid,
    required this.phone,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  String _selectedVehicleType = 'Bike (Scooter)';
  final List<String> _vehicleTypes = [
    'Bike (Scooter)',
    'Auto (Women Driver)',
    'Cab Economy',
    'Cab Premium',
  ];

  final List<String> _sampleAvatars = [
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&fit=crop&crop=faces',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&fit=crop&crop=faces',
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200&fit=crop&crop=faces',
    'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=200&fit=crop&crop=faces',
  ];
  late String _selectedAvatar;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedAvatar = _sampleAvatars[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _vehicleNumberController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final rider = RiderModel(
      uid: widget.uid,
      name: _nameController.text.trim(),
      phone: widget.phone,
      email: _emailController.text.trim(),
      gender: 'Female',
      profileImageUrl: _selectedAvatar,
      vehicleType: _selectedVehicleType,
      vehicleNumber: _vehicleNumberController.text.trim().toUpperCase(),
      emergencyContact: _emergencyContactController.text.trim(),
      documents: {
        'licenseStatus': 'pending',
        'rcStatus': 'pending',
        'submittedAt': DateTime.now().toIso8601String(),
      },
      isOnline: false,
      isVerified: false,
      verificationStatus: 'pending',
      rating: 5.0,
      totalRides: 0,
      role: 'rider',
    );

    try {
      final dbService = RealtimeDbService();
      final authService = context.read<AuthService>();
      final apiService = ApiService(authService: authService);

      // 1. Write to Realtime Database /riders/{uid}
      await dbService.saveRiderData(rider);

      // 2. Call Hostinger PHP Endpoint
      await apiService.registerRider(rider);

      if (mounted) {
        setState(() => _isLoading = false);
        // Navigate to Waiting for Admin Approval screen (NOT /home)
        context.go('/waiting-approval');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration completed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Captain Onboarding'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F6FE), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verification Notice
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EEFD),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEDDCFF)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Captain Verification: Only women drivers are permitted on the Lady Pilot platform.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Avatar Picker
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage: NetworkImage(_selectedAvatar),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Captain Profile Photo',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _sampleAvatars.map((url) {
                            final isSelected = url == _selectedAvatar;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedAvatar = url),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 17,
                                  backgroundImage: NetworkImage(url),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    controller: _nameController,
                    label: 'Captain Full Name *',
                    hintText: 'e.g. Ananya Sharma',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Enter captain name';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hintText: 'e.g. captain@gmail.com',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  // Vehicle Type Selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vehicle Type *',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedVehicleType,
                        items: _vehicleTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Icon(
                                  type.contains('Bike')
                                      ? Icons.electric_scooter_rounded
                                      : (type.contains('Auto') ? Icons.electric_rickshaw_rounded : Icons.directions_car_rounded),
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedVehicleType = val);
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Vehicle Registration Number
                  CustomTextField(
                    controller: _vehicleNumberController,
                    label: 'Vehicle Number *',
                    hintText: 'e.g. KA 05 AB 1234 / AP 05 BK 8989',
                    prefixIcon: const Icon(Icons.pin_rounded, color: AppColors.primary),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Vehicle number is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Emergency SOS Contact Number
                  CustomTextField(
                    controller: _emergencyContactController,
                    label: 'Emergency Family SOS Contact *',
                    hintText: '+91 98765 11111 (Husband / Family)',
                    prefixIcon: const Icon(Icons.shield_outlined, color: AppColors.emergencyRed),
                    keyboardType: TextInputType.phone,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Emergency contact is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  CustomButton(
                    text: 'Complete Captain Setup →',
                    isLoading: _isLoading,
                    onPressed: _handleRegister,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
