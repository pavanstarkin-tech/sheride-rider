import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../data/ride_history_service.dart';
import '../domain/ride_model.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> with SingleTickerProviderStateMixin {
  final RideHistoryService _historyService = RideHistoryService();
  late TabController _tabController;

  String get _currentUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showRideDetailsModal(RideModel ride) {
    final earnings = (ride.fare * 0.85).toStringAsFixed(1);
    final commission = (ride.fare * 0.15).toStringAsFixed(1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Trip ID: ${ride.rideId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                _buildStatusBadge(ride.status),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            _buildDetailRow(Icons.calendar_today_rounded, 'Date & Time', DateTime.fromMillisecondsSinceEpoch(ride.createdAt).toString().substring(0, 16)),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.payments_rounded, 'Passenger Fare', '₹${ride.fare.toStringAsFixed(0)} (${ride.paymentMethod.toUpperCase()})'),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.account_balance_wallet_rounded, 'Your Earnings (85%)', '₹$earnings', isHighlighted: true),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.pie_chart_rounded, 'Platform Fee (15%)', '₹$commission'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Trip Route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.trip_origin, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(ride.pickup.address, style: const TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(ride.drop.address, style: const TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String val, {bool isHighlighted = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isHighlighted ? Colors.green.shade700 : AppColors.primary),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8))),
        Expanded(
          child: Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isHighlighted ? Colors.green.shade800 : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trip History', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'All Trips'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: StreamBuilder<List<RideModel>>(
        stream: _historyService.streamRideHistory(_currentUid),
        builder: (context, snapshot) {
          final allTrips = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTripsList(allTrips),
              _buildTripsList(allTrips.where((r) => r.status == 'completed').toList()),
              _buildTripsList(allTrips.where((r) => r.status == 'cancelled').toList()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTripsList(List<RideModel> trips) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_rounded, size: 64, color: AppColors.secondary.withValues(alpha: 0.8)),
            const SizedBox(height: 12),
            const Text('No trip history found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Completed passenger trips will appear here', style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final ride = trips[index];
        final isCompleted = ride.status == 'completed';
        final netEarnings = (ride.fare * 0.85).toStringAsFixed(0);

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _showRideDetailsModal(ride),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.two_wheeler, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ride.distanceKm} km • ${ride.durationMin} mins',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                              ),
                              Text(
                                DateTime.fromMillisecondsSinceEpoch(ride.createdAt).toString().substring(0, 16),
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isCompleted ? 'Net ₹$netEarnings' : '₹${ride.fare.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: isCompleted ? Colors.green.shade700 : AppColors.textPrimary,
                            ),
                          ),
                          _buildStatusBadge(ride.status),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.circle, color: Colors.green, size: 10),
                          Container(width: 1.5, height: 20, color: Colors.grey.shade300),
                          const Icon(Icons.circle, color: AppColors.primary, size: 10),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ride.pickup.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 10),
                            Text(ride.drop.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    if (status == 'completed') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
    } else if (status == 'cancelled') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
    } else {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
