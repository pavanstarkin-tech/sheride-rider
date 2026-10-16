import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/realtime_db_service.dart';
import '../../../core/services/fcm_token_service.dart';
import '../../../core/widgets/sheride_interactive_map.dart';
import '../../auth/domain/rider_model.dart';
import '../../rides/data/ride_service.dart';
import '../../rides/domain/ride_model.dart';
import '../../rides/presentation/incoming_request_modal.dart';

import '../../profile/presentation/profile_screen.dart';
import '../../rides/presentation/ride_history_screen.dart';
import '../../wallet/presentation/earnings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _riderProfileSub;
  StreamSubscription? _ridesHistorySub;
  final _rideService = RideService();
  final _locationService = LocationService();
  RiderModel? _riderProfile;
  bool _isOnline = false;
  StreamSubscription<List<ActiveRideRequest>>? _activeRequestsSub;
  String? _handledRequestId;
  int _selectedNavIndex = 0;

  double _todayEarnings = 0.0;
  int _todayRidesCount = 0;
  int _totalRidesCount = 0;
  double _avgRating = 5.0;
  int _acceptanceRate = 100;
  List<ActiveRideRequest> _activeRequests = [];
  double _currentLat = 17.0005;
  double _currentLng = 81.7800;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return;
    }
    _locationService.getCurrentPosition().then((pos) {
      if (pos != null && mounted) {
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
        });
      }
    });
    _loadRiderProfile();
  }

  Future<void> _loadRiderProfile() async {
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      if (mounted) context.go('/login');
      return;
    }
    if (uid.isNotEmpty) {
      // 1. Register Captain FCM device token in background
      FcmTokenService().registerRiderFcmToken(uid);

      // 2. Stream rider profile in real-time from Firebase RTDB (reflecting Admin KYC approval/blocking)
      try {
        _riderProfileSub?.cancel();
        _riderProfileSub = FirebaseDatabase.instance.ref('riders/$uid').onValue.listen((event) {
          if (!mounted) return;
          if (!event.snapshot.exists || event.snapshot.value == null) {
            context.go('/onboarding');
            return;
          }
          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          final updatedProfile = RiderModel.fromMap(data, uid: uid);
          final isApproved = updatedProfile.isVerified || updatedProfile.verificationStatus == 'approved';
          if (!isApproved) {
            // Strictly block unapproved captains from the dashboard
            context.go('/waiting-approval');
            return;
          }
          setState(() {
            _riderProfile = updatedProfile;
            // If Admin blocked rider while online, force offline immediately
            if (updatedProfile.isBlocked && _isOnline) {
              _isOnline = false;
              _stopOnlineListeners(uid);
            }
          });
        });
      } catch (_) {}

      // 3. Stream real completed rides and compute true today's earnings & rating
      try {
        _ridesHistorySub?.cancel();
        _ridesHistorySub = FirebaseDatabase.instance
            .ref('rides')
            .orderByChild('riderId')
            .equalTo(uid)
            .onValue
            .listen((event) {
          if (!mounted) return;
          if (event.snapshot.exists && event.snapshot.value != null) {
            final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
            final now = DateTime.now();
            final startOfToday = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

            double todayEarn = 0.0;
            int todayCount = 0;
            int totalCount = 0;
            int cancelledCount = 0;
            double ratingSum = 0.0;
            int ratingCount = 0;

            data.forEach((key, val) {
              if (val is Map) {
                final status = (val['status'] ?? '').toString();
                final fare = (val['fare'] is num) ? (val['fare'] as num).toDouble() : 0.0;
                final createdAt = (val['createdAt'] is num) ? (val['createdAt'] as num).toInt() : 0;
                final rating = (val['passengerRating'] is num) ? (val['passengerRating'] as num).toDouble() : null;

                if (status == 'completed') {
                  totalCount++;
                  if (rating != null && rating > 0) {
                    ratingSum += rating;
                    ratingCount++;
                  }
                  if (createdAt >= startOfToday) {
                    todayCount++;
                    todayEarn += (fare * 0.85); // 85% net captain payout
                  }
                } else if (status == 'cancelled') {
                  cancelledCount++;
                }
              }
            });

            final totalAssigned = totalCount + cancelledCount;
            final acceptance = totalAssigned > 0 ? ((totalCount / totalAssigned) * 100).round() : 100;
            final calculatedRating = ratingCount > 0 ? (ratingSum / ratingCount) : 5.0;

            setState(() {
              _todayEarnings = todayEarn;
              _todayRidesCount = todayCount;
              _totalRidesCount = totalCount;
              _avgRating = calculatedRating;
              _acceptanceRate = acceptance;
            });
          } else {
            setState(() {
              _todayEarnings = 0.0;
              _todayRidesCount = 0;
              _totalRidesCount = 0;
              _avgRating = 5.0;
              _acceptanceRate = 100;
            });
          }
        });
      } catch (_) {}

      final db = RealtimeDbService();
      final profile = await db.getRiderData(uid);
      if (mounted) {
        setState(() {
          _riderProfile = profile;
          _isOnline = (profile?.isOnline ?? false) && !(profile?.isBlocked ?? false);
        });
        if (_isOnline) {
          _startOnlineListeners(uid);
        }
      }
    }
  }

  void _startOnlineListeners(String uid) {
    _locationService.startRiderLocationPublishing(
      uid,
      isOnline: true,
      vehicleType: _riderProfile?.vehicleType,
      riderName: _riderProfile?.name,
    );
    _activeRequestsSub?.cancel();
    _activeRequestsSub = _rideService.listenToActiveRequests(
      riderLat: _currentLat,
      riderLng: _currentLng,
      riderVehicleType: _riderProfile?.vehicleType,
      maxRadiusKm: 15.0,
    ).listen((requests) {
      if (!mounted) return;
      setState(() {
        _activeRequests = requests;
      });
      if (!_isOnline || requests.isEmpty) return;

      final latestRequest = requests.last;
      if (_handledRequestId != latestRequest.rideId) {
        _handledRequestId = latestRequest.rideId;
        _showIncomingRequestModal(latestRequest);
      }
    });
  }

  void _stopOnlineListeners(String uid) {
    _locationService.updateOnlineStatus(uid, false);
    _locationService.stopLocationPublishing();
    _activeRequestsSub?.cancel();
    if (mounted) {
      setState(() {
        _activeRequests = [];
      });
    }
  }

  Future<void> _toggleOnlineStatus(bool val) async {
    if (val) {
      // Security Check: If Admin blocked captain
      if (_riderProfile?.isBlocked == true) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('⚠️ Account Suspended'),
              content: const Text(
                'Your captain account has been temporarily restricted by Lady Pilot Mission Control. Please contact Captain Safety Support for verification.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Notice Check: If KYC rejected
      if (_riderProfile != null && _riderProfile!.verificationStatus == 'rejected') {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('📋 KYC Review Required'),
              content: const Text(
                'Your documents require re-verification by Lady Pilot Mission Control. Please re-upload your driving license in Profile.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    setState(() => _isOnline = val);
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid;
    if (uid != null) {
      final db = RealtimeDbService();
      await db.updateOnlineStatus(uid, val);
      if (val) {
        _startOnlineListeners(uid);
      } else {
        _stopOnlineListeners(uid);
      }
    }
  }

  void _showIncomingRequestModal(ActiveRideRequest req) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IncomingRequestModal(
        request: req,
        rider: _riderProfile ??
            RiderModel(
              uid: context.read<AuthService>().currentUser?.uid ?? '',
              name: context.read<AuthService>().currentUser?.displayName ?? 'Captain',
              phone: context.read<AuthService>().currentUser?.phoneNumber ?? '',
              vehicleNumber: '',
            ),
        onAccept: (acceptedReq) async {
          Navigator.pop(ctx);
          final rider = _riderProfile ??
              RiderModel(
                uid: context.read<AuthService>().currentUser?.uid ?? '',
                name: context.read<AuthService>().currentUser?.displayName ?? 'Captain',
                phone: context.read<AuthService>().currentUser?.phoneNumber ?? '',
                vehicleNumber: '',
              );

          final acceptedRide = await _rideService.acceptRide(rideId: acceptedReq.rideId, rider: rider);

          final rideModel = acceptedRide ?? RideModel(
            rideId: acceptedReq.rideId,
            userId: acceptedReq.userId,
            riderId: rider.uid,
            status: 'accepted',
            pickup: LocationPoint(
              lat: acceptedReq.pickupLat,
              lng: acceptedReq.pickupLng,
              address: acceptedReq.pickupAddress,
              name: acceptedReq.pickupAddress,
            ),
            drop: LocationPoint(
              lat: acceptedReq.dropLat,
              lng: acceptedReq.dropLng,
              address: acceptedReq.dropAddress,
              name: acceptedReq.dropAddress,
            ),
            vehicleType: acceptedReq.vehicleType,
            fare: acceptedReq.fare,
            distanceKm: acceptedReq.distanceKm,
            durationMin: acceptedReq.durationMin,
            otp: acceptedReq.otp,
            riderName: rider.name,
            riderPhone: rider.phone,
            vehicleNumber: rider.vehicleNumber,
          );

          if (mounted) {
            context.push('/active-ride', extra: {
              'ride': rideModel,
              'rider': rider,
            });
          }
        },
        onReject: () {
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  void dispose() {
    _activeRequestsSub?.cancel();
    _riderProfileSub?.cancel();
    _ridesHistorySub?.cancel();
    _locationService.stopLocationPublishing();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final authService = context.read<AuthService>();
    await authService.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedNavIndex,
        children: [
          _buildHomeBody(),
          const EarningsScreen(),
          const RideHistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (idx) => setState(() => _selectedNavIndex = idx),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.two_wheeler_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHomeBody() {
    final name = _riderProfile?.name.isNotEmpty == true ? _riderProfile!.name : 'Captain';
    final vehicle = _riderProfile?.vehicleNumber.isNotEmpty == true ? _riderProfile!.vehicleNumber : '';
    final vehicleType = _riderProfile?.vehicleType.isNotEmpty == true ? _riderProfile!.vehicleType : '';

    return SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Captain Status Bar
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: NetworkImage(
                      _riderProfile?.profileImageUrl.isNotEmpty == true
                          ? _riderProfile!.profileImageUrl
                          : 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
                                const SizedBox(width: 2),
                                Text(
                                  _avgRating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${vehicleType.isNotEmpty ? vehicleType : "Scooty"} • ${vehicle.isNotEmpty ? vehicle : "Vehicle Pending"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // SOS Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.emergencyRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sos_rounded, color: Colors.white, size: 18),
                    ),
                    onPressed: () => context.push('/safety-hub'),
                  ),
                  // Notifications Button
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                    onPressed: () => context.push('/notifications'),
                  ),
                  // Logout Button
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: AppColors.primary),
                    onPressed: _handleLogout,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Online / Offline Switch Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isOnline ? AppColors.success : Colors.grey.shade400,
                        boxShadow: _isOnline
                            ? [
                                BoxShadow(
                                  color: AppColors.success.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOnline ? 'You are ONLINE' : 'You are OFFLINE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _isOnline ? AppColors.success : AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          _isOnline ? 'Listening for nearby ride requests' : 'Switch online to receive rides',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Switch(
                      value: _isOnline,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primaryLight,
                      onChanged: _toggleOnlineStatus,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Today's Earnings Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "TODAY'S EARNINGS",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Daily Instant Payout',
                            style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '₹${_todayEarnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem('Rides Today', '$_todayRidesCount'),
                        _buildStatItem('Total Completed', '$_totalRidesCount'),
                        _buildStatItem('Acceptance', '$_acceptanceRate%'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Interactive Duty Radar Map (Draggable, Web & Mobile)
              Container(
                height: 210,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SheRideInteractiveMap(
                  initialLat: _currentLat,
                  initialLng: _currentLng,
                  initialZoom: 14.5,
                  markers: [
                    // Captain Live Position Marker
                    SheRideMarker(
                      point: ll.LatLng(_currentLat, _currentLng),
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_isOnline ? Colors.green : AppColors.primary).withValues(alpha: 0.22),
                        ),
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOnline ? Colors.green : AppColors.primary,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Center(
                              child: Icon(Icons.two_wheeler_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Plot active incoming requests on map
                    ..._activeRequests.map((req) {
                      return SheRideMarker(
                        point: ll.LatLng(req.pickupLat, req.pickupLng),
                        width: 54,
                        height: 46,
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade800,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '₹${(req.fare * 0.85).round()}',
                                style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.location_on, color: Colors.orange, size: 24),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Live Incoming Ride Queue / Radar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Incoming Ride Queue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isOnline ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isOnline ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                          size: 14,
                          color: _isOnline ? Colors.green.shade700 : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isOnline ? '${_activeRequests.length} active nearby' : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _isOnline ? Colors.green.shade800 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // If real incoming ride requests exist, display them!
              if (_activeRequests.isNotEmpty)
                ..._activeRequests.map((req) {
                  final netEarn = (req.fare * 0.85).toStringAsFixed(0);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
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
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.two_wheeler_rounded, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.userName.isNotEmpty ? req.userName : 'Women Passenger 🌸',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                Text(
                                  '${req.distanceKm} km • ${req.durationMin} mins',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Net ₹$netEarn',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.green,
                                  ),
                                ),
                                Text('Fare ₹${req.fare.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFF5F5F5)),
                        const SizedBox(height: 10),
                        _buildRouteRow(Icons.radio_button_checked_rounded, Colors.green, req.pickupAddress),
                        const SizedBox(height: 6),
                        _buildRouteRow(Icons.location_on_rounded, AppColors.primary, req.dropAddress),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () => _showIncomingRequestModal(req),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('VIEW & ACCEPT RIDE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  );
                })
              else
                // Clean live radar empty state (NO mock cards!)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _isOnline ? Colors.green.shade100 : Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isOnline ? Colors.green.shade50 : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isOnline ? Icons.radar_rounded : Icons.power_settings_new_rounded,
                          size: 36,
                          color: _isOnline ? Colors.green.shade600 : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isOnline ? 'Radar Active • Searching for Rides' : 'You are Currently Offline',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _isOnline ? Colors.green.shade800 : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isOnline
                            ? 'You are online and visible to nearby women passengers in Rajahmundry. Incoming ride alerts will pop up automatically with sound chime.'
                            : 'Switch the toggle above to go Online. Passenger ride requests in your area will appear here immediately.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.8), height: 1.4),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildRouteRow(IconData icon, Color iconColor, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
