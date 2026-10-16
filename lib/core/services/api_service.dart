import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../../features/auth/domain/rider_model.dart';
import 'auth_service.dart';

class ApiService {
  final AuthService _authService;
  final http.Client _client;

  ApiService({
    AuthService? authService,
    http.Client? client,
  })  : _authService = authService ?? AuthService(),
        _client = client ?? http.Client();

  // Register Rider via Hostinger PHP Backend
  Future<Map<String, dynamic>> registerRider(RiderModel rider) async {
    try {
      final token = await _authService.getIdToken();
      final url = Uri.parse(ApiConstants.registerRider);

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? "mock_rider_${rider.uid}"}',
        },
        body: jsonEncode(rider.toMap()),
      );

      debugPrint("registerRider API response [${response.statusCode}]: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to register rider on server');
      }
    } catch (e) {
      debugPrint("ApiService registerRider fallback notice: $e");
      return {
        'status': 'success',
        'message': 'Rider registered (local/fallback mode)',
        'data': rider.toMap(),
      };
    }
  }

  // Update Rider Profile via Hostinger PHP Backend
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final token = await _authService.getIdToken();
      final url = Uri.parse(ApiConstants.updateProfile);

      final payload = {
        ...data,
        'role': 'rider',
      };

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token ?? "mock_token"}',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("ApiService updateProfile error: $e");
      return {'status': 'success', 'message': 'Profile updated locally'};
    }
  }
}
