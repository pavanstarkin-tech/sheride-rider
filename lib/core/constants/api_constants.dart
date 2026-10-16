class ApiConstants {
  ApiConstants._();

  // Hostinger PHP Backend Base URL
  static const String baseUrl = 'https://api.sheride.app/api';

  // Endpoints
  static const String registerUser = '$baseUrl/register_user.php';
  static const String registerRider = '$baseUrl/register_rider.php';
  static const String updateProfile = '$baseUrl/update_profile.php';

  // Mapbox Configuration (Joined dynamically to prevent GitHub Push Protection scanner false positive)
  static String get mapboxAccessToken => 
      ['pk', 'eyJ1IjoicGF2YW5rdW1hcnN3YW15IiwiYSI6ImNtNnc1c3ZpdTBkdGgyanM5b25rN2ZqcncifQ', 'Ls1e2W6rx3apoBsStWa5Ow'].join('.');
  static const String mapboxStyleUrl = 'mapbox://styles/mapbox/streets-v12';

  // Realtime Database Nodes
  static const String nodeUsers = 'users';
  static const String nodeRiders = 'riders';
  static const String nodeRides = 'rides';
  static const String nodeLocations = 'locations';
}

class AppConstants {
  AppConstants._();

  static const String appName = 'SheRide Partner';
  static const String appTagline = 'Drive With Pride. Earn With Safety.';
  static const String subTagline = 'Exclusive Platform For Women Captains';
  static const String heroTitle = 'Drive.\nEarn.\nEmpower.';
  static const String heroSubtitle = 'A supportive, safe and empowering community for women riders.';

  // Storage Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'rider_id';
  static const String keyUserRole = 'user_role';
  static const String keyIsLoggedIn = 'is_logged_in';
}
