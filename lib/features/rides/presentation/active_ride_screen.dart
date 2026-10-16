import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/location_service.dart';
import '../../../core/widgets/sheride_interactive_map.dart';
import '../../auth/domain/rider_model.dart';
import '../../auth/presentation/widgets/custom_button.dart';
import '../../wallet/data/wallet_service.dart';
import '../data/ride_service.dart';
import '../domain/ride_model.dart';

class ActiveRideScreen extends StatefulWidget {
  final RideModel ride;
  final RiderModel rider;

  const ActiveRideScreen({
    super.key,
    required this.ride,
    required this.rider,
  });

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  static const _pipChannel = MethodChannel('com.sheride.rider/pip');
  final _rideService = RideService();
  final _otpController = TextEditingController();
  late RideModel _currentRide;
  StreamSubscription<RideModel?>? _rideSub;
  StreamSubscription<Position>? _positionSub;
  Position? _captainPosition;
  bool _isLoading = false;
  mb.MapboxMap? _mapboxMap;

  @override
  void initState() {
    super.initState();
    _currentRide = widget.ride;
    _captainPosition = LocationService().lastKnownPosition;
    _initCaptainLocation();
    _listenToRide();
    _setPipAllowed(true);
  }

  Future<void> _enterPipMode() async {
    try {
      await _pipChannel.invokeMethod('enterPip');
    } catch (_) {}
  }

  Future<void> _setPipAllowed(bool allowed) async {
    try {
      await _pipChannel.invokeMethod('setPipAllowed', {'allowed': allowed});
    } catch (_) {}
  }

  Future<void> _initCaptainLocation() async {
    final pos = await LocationService().getCurrentPosition();
    if (pos != null && mounted) {
      setState(() => _captainPosition = pos);
      _updateMapCamera();
    }
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((p) {
      if (mounted) {
        setState(() => _captainPosition = p);
      }
    });
  }

  Future<void> _openGoogleMapsNavigation(double lat, double lng, String label) async {
    final googleMapsNavUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final googleMapsWebUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsNavUri)) {
        await launchUrl(googleMapsNavUri, mode: LaunchMode.externalNonBrowserApplication);
      } else if (await canLaunchUrl(googleMapsWebUri)) {
        await launchUrl(googleMapsWebUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(googleMapsWebUri, mode: LaunchMode.externalApplication);
      }
      // Trigger native Picture-in-Picture floating mini-window over Google Maps
      await Future.delayed(const Duration(milliseconds: 250));
      await _enterPipMode();
    } catch (e) {
      debugPrint('Error launching Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening maps: $e')),
        );
      }
    }
  }

  void _listenToRide() {
    _rideSub = _rideService.streamRide(widget.ride.rideId).listen((updated) {
      if (updated != null && mounted) {
        setState(() => _currentRide = updated);
        _updateMapCamera();
        if (updated.status == 'cancelled') {
          final isByAdmin = updated.cancelledBy == 'admin';
          final msg = isByAdmin
              ? '⚠️ Ride cancelled by Lady Pilot Admin Mission Control${updated.cancelReason != null ? ": ${updated.cancelReason}" : ""}'
              : 'Ride was cancelled by passenger';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error, duration: const Duration(seconds: 4)),
          );
          context.go('/home');
        } else if (updated.status == 'completed' && _currentRide.status != 'completed') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Ride marked as completed by Lady Pilot Mission Control!'), backgroundColor: Colors.green),
          );
          context.go('/home');
        }
      }
    });
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    try {
      mapboxMap.location.updateSettings(
        mb.LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          showAccuracyRing: true,
        ),
      );
    } catch (_) {}
    _updateMapCamera();
  }

  void _updateMapCamera() {
    if (_mapboxMap == null) return;
    final target = _currentRide.status == 'started' ? _currentRide.drop : _currentRide.pickup;
    _mapboxMap?.setCamera(mb.CameraOptions(
      center: mb.Point(coordinates: mb.Position(target.lng, target.lat)),
      zoom: 14.5,
    ));
  }

  @override
  void dispose() {
    _setPipAllowed(false);
    _rideSub?.cancel();
    _positionSub?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleArrivedAtPickup() async {
    setState(() => _isLoading = true);
    await _rideService.updateRideStatus(_currentRide.rideId, 'arrived');
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleStartRide() async {
    final enteredOtp = _otpController.text.trim();
    if (enteredOtp.isEmpty || enteredOtp != _currentRide.otp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid PIN. Please ask the passenger for their 4-digit ride OTP.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await _rideService.updateRideStatus(_currentRide.rideId, 'started', otp: enteredOtp);
    if (mounted) {
      setState(() => _isLoading = false);
      _updateMapCamera();
    }
  }

  Future<void> _handleCompleteRide() async {
    setState(() => _isLoading = true);
    await _rideService.updateRideStatus(
      _currentRide.rideId,
      'completed',
      riderId: widget.rider.uid,
    );
    await WalletService().creditRideEarnings(
      widget.rider.uid,
      _currentRide.fare,
      _currentRide.rideId,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      _showCompletionSheet();
    }
  }

  Future<void> _handleCancelRide() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
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
              'Cancel Ride',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Please select a reason for cancelling this ride assignment:',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...[
              'Passenger requested cancellation',
              'Passenger did not show up',
              'Incorrect / unreachable pickup point',
              'Vehicle issue or flat tyre',
              'Heavy traffic / emergency',
            ].map(
              (r) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.radio_button_unchecked, color: AppColors.primary, size: 20),
                title: Text(r, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, r),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (reason != null && mounted) {
      setState(() => _isLoading = true);
      await _rideService.updateRideStatus(
        _currentRide.rideId,
        'cancelled',
        riderId: widget.rider.uid,
        cancelledBy: 'rider',
      );
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ride cancelled: $reason'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
        context.go('/home');
      }
    }
  }

  void _showCompletionSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'Ride Completed Successfully! 🌸',
                style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Collect cash / UPI payment from passenger',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                '₹${_currentRide.fare.toInt()}',
                style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Return to Online Home',
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/home');
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _currentRide.status;
    final isEnRouteToPickup = status == 'accepted' || status == 'arrived';
    final target = (status == 'started') ? _currentRide.drop : _currentRide.pickup;

    final media = MediaQuery.of(context);
    final isPipMode = media.size.height < 320 || media.size.width < 320;

    if (isPipMode) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status == 'started' ? 'To Drop: ${_currentRide.drop.address}' : 'To Pickup: ${_currentRide.pickup.address}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EEFD),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PIN: ${_currentRide.otp}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () {
                      if (status == 'accepted') {
                        _handleArrivedAtPickup();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      status == 'accepted'
                          ? 'Arrived at Pickup'
                          : (status == 'arrived' ? 'Awaiting Start PIN' : 'Trip in Progress 🌸'),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Real-time live origin from captain's device GPS
    final originLat = _captainPosition?.latitude ?? (isEnRouteToPickup ? (_currentRide.pickup.lat - 0.005) : _currentRide.pickup.lat);
    final originLng = _captainPosition?.longitude ?? (isEnRouteToPickup ? (_currentRide.pickup.lng - 0.005) : _currentRide.pickup.lng);
    final destLat = target.lat;
    final destLng = target.lng;

    final routePoints = [
      ll.LatLng(originLat, originLng),
      ll.LatLng(destLat, destLng),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive Driving Route Map View (Web: Gesture-friendly OpenStreetMap/Carto, Mobile: Mapbox)
            Positioned.fill(
              bottom: 270,
              child: kIsWeb
                  ? SheRideInteractiveMap(
                      initialLat: (originLat + destLat) / 2,
                      initialLng: (originLng + destLng) / 2,
                      initialZoom: 14.2,
                      routePoints: routePoints,
                      markers: [
                        // Captain Live Position Pin
                        SheRideMarker(
                          point: ll.LatLng(originLat, originLng),
                          width: 50,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.25),
                            ),
                            child: Center(
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
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
                        // Pickup Marker
                        SheRideMarker(
                          point: ll.LatLng(_currentRide.pickup.lat, _currentRide.pickup.lng),
                          width: 60,
                          height: 50,
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C853),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('PICKUP', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                              const Icon(Icons.location_on_rounded, color: Color(0xFF00C853), size: 26),
                            ],
                          ),
                        ),
                        // Drop Marker
                        SheRideMarker(
                          point: ll.LatLng(_currentRide.drop.lat, _currentRide.drop.lng),
                          width: 60,
                          height: 50,
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('DROP', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                              const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 26),
                            ],
                          ),
                        ),
                      ],
                    )
                  : mb.MapWidget(
                      cameraOptions: mb.CameraOptions(
                        center: mb.Point(coordinates: mb.Position((originLng + destLng) / 2, (originLat + destLat) / 2)),
                        zoom: 14.0,
                      ),
                      styleUri: ApiConstants.mapboxStyleUrl,
                      onMapCreated: _onMapCreated,
                    ),
            ),

            // Floating "Open in Google Maps" Navigation Button
            Positioned(
              right: 16,
              bottom: 285,
              child: ElevatedButton.icon(
                onPressed: () => _openGoogleMapsNavigation(
                  destLat,
                  destLng,
                  status == 'started' ? 'Drop Location' : 'Pickup Location',
                ),
                icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                label: Text(
                  status == 'started' ? 'Google Maps: Drop 🗺️' : 'Google Maps: Pickup 🗺️',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8), // Google Navigation Blue
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
              ),
            ),

            // Top Status & Navigation Badge
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status == 'accepted'
                              ? Icons.navigation_rounded
                              : (status == 'arrived' ? Icons.pin_drop_rounded : Icons.sports_motorsports_rounded),
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status == 'accepted'
                              ? 'Driving to Pickup'
                              : (status == 'arrived' ? 'At Pickup Point' : 'En Route to Drop'),
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // SOS Emergency Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.emergencyRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sos_rounded, color: Colors.white, size: 20),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('CAPTAIN EMERGENCY SOS TRIGGERED! 24/7 Desk Alerted.'),
                          backgroundColor: AppColors.emergencyRed,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom Action Control Sheet
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 14),

                    // Passenger Details
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundColor: Color(0xFFF0EEFD),
                          child: Icon(Icons.person, color: Color(0xFF7F00FD), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentRide.userName?.isNotEmpty == true ? _currentRide.userName! : 'Women Passenger',
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              Text(
                                '100% Female Verified • ${_currentRide.paymentMethod.toUpperCase()}',
                                style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF0EEFD), borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            '₹${_currentRide.fare.toInt()}',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F1F1)),
                    const SizedBox(height: 12),

                    // Location Address
                    Row(
                      children: [
                        Icon(
                          status == 'started' ? Icons.location_on_rounded : Icons.radio_button_checked_rounded,
                          color: status == 'started' ? AppColors.primary : Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status == 'started'
                                ? 'Drop: ${_currentRide.drop.name?.isNotEmpty == true ? _currentRide.drop.name! : _currentRide.drop.address}'
                                : 'Pickup: ${_currentRide.pickup.name?.isNotEmpty == true ? _currentRide.pickup.name! : _currentRide.pickup.address}',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Step 1: Accepted -> Buttons "Google Maps" & "Arrived at Pickup"
                    if (status == 'accepted') ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openGoogleMapsNavigation(
                                _currentRide.pickup.lat,
                                _currentRide.pickup.lng,
                                'Pickup Location',
                              ),
                              icon: const Icon(Icons.turn_right_rounded, color: Color(0xFF1A73E8), size: 18),
                              label: const Text('Open Maps', style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: CustomButton(
                              text: 'Arrived at Pickup →',
                              isLoading: _isLoading,
                              onPressed: _handleArrivedAtPickup,
                            ),
                          ),
                        ],
                      ),
                    ]
                    // Step 2: Arrived -> OTP Input + "Start Ride"
                    else if (status == 'arrived') ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 6),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: 'Enter 4-digit PIN',
                                filled: true,
                                fillColor: const Color(0xFFF0EEFD),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomButton(
                              text: 'Start Ride',
                              isLoading: _isLoading,
                              onPressed: _handleStartRide,
                            ),
                          ),
                        ],
                      ),
                    ]
                    // Step 3: Started -> Button "Complete Ride"
                    else if (status == 'started') ...[
                      CustomButton(
                        text: 'Complete Ride & Collect ₹${_currentRide.fare.toInt()} →',
                        backgroundColor: Colors.green,
                        isLoading: _isLoading,
                        onPressed: _handleCompleteRide,
                      ),
                    ],

                    // Cancel Option for Captain before Ride Starts
                    if (status == 'accepted' || status == 'arrived') ...[
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton.icon(
                          onPressed: _isLoading ? null : _handleCancelRide,
                          icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                          label: Text(
                            'Cancel Ride',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
