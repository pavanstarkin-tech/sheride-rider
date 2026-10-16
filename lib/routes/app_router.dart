import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/domain/rider_model.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/edit_rider_profile_screen.dart';
import '../features/profile/presentation/documents_kyc_screen.dart';
import '../features/profile/presentation/incentives_quests_screen.dart';
import '../features/profile/presentation/rider_settings_screen.dart';
import '../features/rides/domain/ride_model.dart';
import '../features/rides/presentation/active_ride_screen.dart';
import '../features/rides/presentation/ride_history_screen.dart';
import '../features/safety/presentation/rider_safety_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/auth/presentation/captain_intro_screen.dart';
import '../features/auth/presentation/captain_onboarding_screen.dart';
import '../features/auth/presentation/waiting_approval_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/wallet/presentation/earnings_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      final user = FirebaseAuth.instance.currentUser;
      final location = state.matchedLocation;
      final publicRoutes = ['/', '/intro', '/welcome', '/login', '/otp', '/register'];

      // If user is NOT logged in and trying to access any protected screen
      if (user == null && !publicRoutes.contains(location)) {
        return '/intro';
      }

      // If user IS logged in and trying to access auth/intro screens, redirect to home
      if (user != null && (location == '/intro' || location == '/welcome' || location == '/login' || location == '/otp')) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/intro',
        builder: (context, state) => const CaptainIntroScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const CaptainIntroScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const CaptainOnboardingScreen(),
      ),
      GoRoute(
        path: '/waiting-approval',
        builder: (context, state) => const WaitingApprovalScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OtpScreen(
            verificationId: extra['verificationId'] ?? '',
            phoneNumber: extra['phoneNumber'] ?? '',
            resendToken: extra['resendToken'],
          );
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return RegisterScreen(
            uid: extra['uid'] ?? 'rider_${DateTime.now().millisecondsSinceEpoch}',
            phone: extra['phone'] ?? '+919876543210',
          );
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/active-ride',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
          final ride = extra['ride'] as RideModel? ??
              RideModel(
                rideId: 'ride_active',
                userId: '',
                riderId: currentUid,
                status: 'accepted',
                pickup: const LocationPoint(lat: 17.0005, lng: 81.7800, address: 'Pickup Location'),
                drop: const LocationPoint(lat: 17.0520, lng: 81.8210, address: 'Destination'),
                vehicleType: 'scooty',
                fare: 0,
                distanceKm: 0,
                durationMin: 0,
                otp: '',
              );
          final rider = extra['rider'] as RiderModel? ??
              RiderModel(
                uid: '',
                name: 'Captain',
                phone: '',
                vehicleNumber: '',
              );
          return ActiveRideScreen(ride: ride, rider: rider);
        },
      ),
      GoRoute(
        path: '/earnings',
        builder: (context, state) => const EarningsScreen(),
      ),
      GoRoute(
        path: '/ride-history',
        builder: (context, state) => const RideHistoryScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) {
          final rider = state.extra as RiderModel?;
          return EditRiderProfileScreen(initialProfile: rider);
        },
      ),
      GoRoute(
        path: '/documents-kyc',
        builder: (context, state) => const DocumentsKycScreen(),
      ),
      GoRoute(
        path: '/incentives-quests',
        builder: (context, state) => const IncentivesQuestsScreen(),
      ),
      GoRoute(
        path: '/rider-settings',
        builder: (context, state) => const RiderSettingsScreen(),
      ),
      GoRoute(
        path: '/safety-hub',
        builder: (context, state) => const RiderSafetyScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}
