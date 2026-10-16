import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../data/support_service.dart';
import '../domain/support_ticket_model.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final SupportService _supportService = SupportService();
  final TextEditingController _searchController = TextEditingController();
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateTicketSheet({String category = 'payout'}) {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String currentCat = category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
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
              const Text('Captain Support Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Our priority captain desk will reply within 10 mins.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.8))),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: currentCat,
                decoration: InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: [
                  const DropdownMenuItem(value: 'payout', child: Text('💰 Earnings & Bank Payout')),
                  const DropdownMenuItem(value: 'safety', child: Text('🚨 Captain Safety Concern')),
                  const DropdownMenuItem(value: 'incentives', child: Text('🎯 Weekly Quest / Incentive')),
                  const DropdownMenuItem(value: 'vehicle', child: Text('🛵 Vehicle & Documents KYC')),
                  const DropdownMenuItem(value: 'other', child: Text('❓ General Inquiry')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => currentCat = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message / Details',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final subj = subjectController.text.trim();
                    final msg = messageController.text.trim();
                    if (subj.isNotEmpty && msg.isNotEmpty) {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      await _supportService.createTicket(
                        uid: _currentUid,
                        category: currentCat,
                        subject: subj,
                        message: msg,
                      );
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Support ticket raised! Captain help desk is processing it. 🌸'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                      if (mounted) {
                        setState(() {});
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Captain Help Desk', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
              Row(
                children: [
                  Expanded(
                    child: _buildHelpCard(
                      icon: Icons.phone_in_talk_rounded,
                      title: 'Captain Hotline',
                      subtitle: '24/7 Priority Desk',
                      color: Colors.green.shade700,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Calling Captain Priority Hotline: 1800-SHERIDE-CAPTAIN...')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildHelpCard(
                      icon: Icons.add_circle_outline_rounded,
                      title: 'New Ticket',
                      subtitle: 'Direct Message',
                      color: AppColors.primary,
                      onTap: () => _showCreateTicketSheet(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Help Topics for Captains',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              _buildTopicItem('💰 Instant Payout & UPI Bank Verification', 'payout'),
              _buildTopicItem('🛡️ Female Passenger Safety & SOS Policy', 'safety'),
              _buildTopicItem('🎁 Weekly Bonus Quests & Incentive Tiers', 'incentives'),
              _buildTopicItem('📄 Renewing Driving License & RC Documents', 'vehicle'),
              const SizedBox(height: 24),
              const Text(
                'Previous Inquiries',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),
              StreamBuilder<List<SupportTicketModel>>(
                stream: _supportService.streamTickets(_currentUid),
                builder: (context, snapshot) {
                  final tickets = snapshot.data ?? [];
                  if (tickets.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: const Center(child: Text('No previous inquiries.', style: TextStyle(color: AppColors.textSecondary))),
                    );
                  }
                  return Column(
                    children: tickets.map((t) => _buildTicketRow(t)).toList(),
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpCard({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicItem(String text, String cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        onTap: () => _showCreateTicketSheet(category: cat),
      ),
    );
  }

  Widget _buildTicketRow(SupportTicketModel ticket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(ticket.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ticket.status == 'resolved' ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ticket.status.toUpperCase(),
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ticket.status == 'resolved' ? Colors.green.shade800 : Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
