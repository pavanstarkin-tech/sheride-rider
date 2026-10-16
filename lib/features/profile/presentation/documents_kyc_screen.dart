import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class DocumentsKycScreen extends StatefulWidget {
  const DocumentsKycScreen({super.key});

  @override
  State<DocumentsKycScreen> createState() => _DocumentsKycScreenState();
}

class _DocumentsKycScreenState extends State<DocumentsKycScreen> {
  StreamSubscription? _docSubscription;
  Map<String, dynamic> _documents = {};
  String _overallStatus = 'approved';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToKycDocuments();
  }

  @override
  void dispose() {
    _docSubscription?.cancel();
    super.dispose();
  }

  void _listenToKycDocuments() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    _docSubscription = FirebaseDatabase.instance.ref('riders/$uid').onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final docs = data['documents'] != null ? Map<String, dynamic>.from(data['documents'] as Map) : <String, dynamic>{};
        final vStatus = (data['verificationStatus'] ?? (data['isVerified'] == true ? 'approved' : 'pending')).toString();

        setState(() {
          _documents = docs;
          _overallStatus = vStatus;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  void _showUpdateDocumentModal(String docType, String currentVal) {
    final controller = TextEditingController(text: currentVal);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              const SizedBox(height: 16),
              Text(
                'Update $docType',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter updated certificate / registration number for Mission Control verification.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                decoration: InputDecoration(
                  labelText: '$docType Number',
                  filled: true,
                  fillColor: const Color(0xFFF9F7FD),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final newVal = controller.text.trim();
                    if (newVal.isEmpty) return;
                    Navigator.pop(ctx);
                    await _submitDocumentUpdate(docType, newVal);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Submit for Verification', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitDocumentUpdate(String docType, String value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final docKey = docType.toLowerCase().replaceAll(' ', '_');
      await FirebaseDatabase.instance.ref('riders/$uid/documents/$docKey').set({
        'number': value,
        'status': 'under_review',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Write Admin Audit Log entry
      await FirebaseDatabase.instance.ref('adminLogs').push().set({
        'action': 'rider_kyc_reupload',
        'targetId': uid,
        'docType': docType,
        'number': value,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🌸 $docType submitted to Mission Control for verification!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating document: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = _overallStatus == 'approved';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Document & KYC Hub', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Hero Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isApproved
                              ? [const Color(0xFF10B981), const Color(0xFF059669)]
                              : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: (isApproved ? Colors.green : Colors.amber).withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isApproved ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isApproved ? 'KYC 100% Verified 🌸' : 'KYC Review in Progress',
                                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isApproved
                                      ? 'You are fully authorized to accept rides across all city zones.'
                                      : 'Mission Control is reviewing your documents. You can still demo-drive.',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Mandatory Verification Documents',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    // Document 1: Driving License
                    _buildDocumentCard(
                      title: 'Driving License (DL)',
                      docKey: 'driving_license',
                      icon: Icons.badge_rounded,
                      defaultNumber: 'DL-052021008492',
                      description: 'Valid permanent two-wheeler / transport motor license',
                      status: _documents['driving_license']?['status'] ?? (isApproved ? 'verified' : 'under_review'),
                    ),
                    const SizedBox(height: 14),

                    // Document 2: Vehicle RC Book
                    _buildDocumentCard(
                      title: 'Vehicle Registration (RC)',
                      docKey: 'vehicle_rc',
                      icon: Icons.electric_moped_rounded,
                      defaultNumber: 'AP 05 AB 1234',
                      description: 'Valid RC certificate matching your active ride category',
                      status: _documents['vehicle_rc']?['status'] ?? (isApproved ? 'verified' : 'under_review'),
                    ),
                    const SizedBox(height: 14),

                    // Document 3: Aadhaar Card
                    _buildDocumentCard(
                      title: 'Aadhaar Identity Verification',
                      docKey: 'aadhaar_card',
                      icon: Icons.fingerprint_rounded,
                      defaultNumber: 'XXXX-XXXX-4912',
                      description: 'Government of India UIDAI identity verification',
                      status: _documents['aadhaar_card']?['status'] ?? (isApproved ? 'verified' : 'under_review'),
                    ),
                    const SizedBox(height: 14),

                    // Document 4: Police Clearance Certificate
                    _buildDocumentCard(
                      title: 'Women Safety & Police Clearance',
                      docKey: 'police_clearance',
                      icon: Icons.security_rounded,
                      defaultNumber: 'PCC-2026-LADY PILOT-0941',
                      description: 'Official police background record check for women passengers',
                      status: _documents['police_clearance']?['status'] ?? (isApproved ? 'verified' : 'under_review'),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String docKey,
    required IconData icon,
    required String defaultNumber,
    required String description,
    required String status,
  }) {
    final docNumber = _documents[docKey]?['number'] ?? defaultNumber;
    final isVerified = status == 'verified' || status == 'approved';

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      docNumber,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isVerified ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isVerified ? Colors.green.shade200 : Colors.amber.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVerified ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      size: 13,
                      color: isVerified ? Colors.green.shade700 : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isVerified ? 'Verified' : 'Under Review',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isVerified ? Colors.green.shade800 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showUpdateDocumentModal(title, docNumber),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Update / Re-upload', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
