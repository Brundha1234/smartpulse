// lib/services/api_service.dart
//
// SmartPulse v2 — API Service
// Talks to the Flask backend at BASE_URL.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/prediction_result.dart';

class ApiService {
  static const String _configuredBaseUrl =
      String.fromEnvironment('SMARTPULSE_API_URL', defaultValue: '');

  // Configurable backend URL with fallbacks
  static String _baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : 'http://127.0.0.1:3000';

  // Public getter for base URL
  static String get baseUrl => _baseUrl;

  // Initialize with fallback URLs
  static Future<void> initializeBackendUrl() async {
    if (_configuredBaseUrl.isNotEmpty) {
      _baseUrl = _configuredBaseUrl;
      return;
    }

    // First try to auto-detect common gateway IPs
    final gatewayUrls = await _getPossibleGatewayUrls();

    // Combine with fallback URLs
    final urls = [
      ...gatewayUrls,
      'http://127.0.0.1:3000',
      'http://localhost:3000',
      'http://10.0.2.2:3000',
      'http://10.0.0.2:3000',
      'http://127.0.0.1:5000', // Local backend - for testing on laptop
      'http://localhost:5000', // Localhost alternative
      'http://192.168.1.100:5000', // Common home network
      'http://192.168.0.100:5000', // Alternative home network
      'http://10.0.0.2:5000', // Alternative WiFi IP
      'http://10.0.2.2:5000', // Android emulator to host
      'http://172.16.0.1:5000', // VPN network
      'http://169.254.0.1:5000', // Link-local
    ];

    for (String url in urls) {
      try {
        // Trying to connect to: $url
        final response = await http
            .get(Uri.parse('$url/'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _baseUrl = url;
          // Connected to backend: $url
          return;
        }
      } catch (e) {
        // Failed to connect to $url: $e
        continue;
      }
    }
    // No backend connection found. Using default: $_baseUrl
    //   1. Backend server is running (python app.py)
    //   2. Device and computer are on same WiFi network
    //   3. Firewall is not blocking port 5000
    //   4. Update YOUR_COMPUTER_IP in api_service.dart
    //   5. Your computer IP: ${await _getLocalIP()}

    // Keep trying - don't fall back to demo mode
    // Will keep trying to connect...
  }

  // Auto-detect possible gateway URLs based on network interfaces
  static Future<List<String>> _getPossibleGatewayUrls() async {
    final urls = <String>[];

    try {
      // Get network interfaces
      final interfaces = await NetworkInterface.list(
          includeLoopback: false, includeLinkLocal: false);

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            // Generate possible gateway URLs for this network
            final gatewayUrl = _getGatewayUrl(ip);
            if (gatewayUrl != null && !urls.contains(gatewayUrl)) {
              urls.add(gatewayUrl);
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Error detecting network interfaces: $e');
    }

    // Add common gateway IPs as fallback
    urls.addAll([
      'http://192.168.137.1:3000',
      'http://192.168.43.1:3000',
      'http://10.0.12.163:3000',
      'http://192.168.137.1:5000', // Windows hotspot
      'http://192.168.43.1:5000', // Android hotspot
      'http://10.0.12.163:5000', // Your current WiFi IP
    ]);

    return urls;
  }

  // Get gateway URL based on IP address
  static String? _getGatewayUrl(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;

    try {
      final a = int.parse(parts[0]);
      final b = int.parse(parts[1]);
      final c = int.parse(parts[2]);

      // Common gateway patterns
      if (a == 192 && b == 168) {
        return 'http://192.168.$c.1:5000'; // Common home network
      } else if (a == 10) {
        return 'http://10.$b.$c.1:5000'; // Class A private network
      } else if (a == 172 && b >= 16 && b <= 31) {
        return 'http://172.$b.$c.1:5000'; // Class B private network
      }
    } catch (e) {
      return null;
    }

    return null;
  }

  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // Check if backend is available
  static Future<bool> checkBackendConnection() async {
    try {
      print('🔍 Checking backend connection to: $_baseUrl');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/'),
          )
          .timeout(const Duration(seconds: 5));

      print('📡 Backend response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ Backend connection successful');
        return true;
      } else {
        print('⚠️ Backend returned status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Authentication methods
  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    const maxRetries = 2;
    int retryCount = 0;

    while (retryCount <= maxRetries) {
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/auth/register'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(userData),
            )
            .timeout(const Duration(seconds: 15));

        final responseData = json.decode(response.body);

        if (response.statusCode == 201) {
          return {
            'success': true,
            'user': responseData['user'],
            'token': responseData['token'],
            'message': responseData['message'],
          };
        } else {
          return {
            'success': false,
            'message': responseData['error'] ?? 'Registration failed',
          };
        }
      } catch (e) {
        retryCount++;

        if (retryCount <= maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        } else {
          return {
            'success': false,
            'message': 'Network error: ${e.toString()}',
          };
        }
      }
    }

    return {
      'success': false,
      'message': 'Registration failed after multiple attempts',
    };
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    const maxRetries = 2;
    int retryCount = 0;

    while (retryCount <= maxRetries) {
      try {
        final response = await http
            .post(
              Uri.parse('$_baseUrl/auth/login'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'email': email,
                'password': password,
              }),
            )
            .timeout(const Duration(seconds: 15));

        final responseData = json.decode(response.body);

        if (response.statusCode == 200) {
          setToken(responseData['token']);
          return {
            'success': true,
            'user': responseData['user'],
            'token': responseData['token'],
            'message': responseData['message'],
          };
        } else {
          return {
            'success': false,
            'message': responseData['error'] ?? 'Login failed',
          };
        }
      } catch (e) {
        retryCount++;

        if (retryCount <= maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        } else {
          return {
            'success': false,
            'message': 'Network error: ${e.toString()}',
          };
        }
      }
    }

    return {
      'success': false,
      'message': 'Login failed after multiple attempts',
    };
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/profile'),
        headers: _headers,
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': responseData['user'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Failed to get profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> updateData) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/user/profile'),
            headers: _headers,
            body: json.encode(updateData),
          )
          .timeout(const Duration(seconds: 15));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': responseData['user'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> savePrediction(
      Map<String, dynamic> predictionData) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/user/prediction'),
        headers: _headers,
        body: json.encode(predictionData),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'prediction_id': responseData['prediction_id'],
          'message': responseData['message'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Failed to save prediction',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<PredictionResult> predict({
    required double screenTime,
    required double appUsage,
    required double nightUsage,
    required int unlockCount,
    required int notificationCount,
    required int stress,
    required int anxiety,
    required int depression,
    Map<String, double> appBreakdown = const {},
    int? peakHour,
    bool? isWeekend,
  }) async {
    final uri = Uri.parse('$_baseUrl/predict');
    final body = json.encode({
      'screen_time': screenTime,
      'app_usage': appUsage,
      'night_usage': nightUsage,
      'unlock_count': unlockCount,
      'notification_count': notificationCount,
      'app_breakdown': appBreakdown,
      'peak_hour': peakHour,
      'is_weekend': isWeekend,
      'stress': stress,
      'anxiety': anxiety,
      'depression': depression,
    });

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return PredictionResult.fromJson(
        Map<String, dynamic>.from(json.decode(response.body) as Map),
      );
    }
    throw Exception('Prediction failed: ${response.body}');
  }

  static Future<Map<String, dynamic>> analyzeWeek(
      List<Map<String, dynamic>> days) async {
    final uri = Uri.parse('$_baseUrl/analyze');
    final body = json.encode({'days': days});
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Weekly analysis failed: ${response.body}');
  }

  static Future<Map<String, dynamic>> modelInfo() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/model/info'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Model info failed');
  }
}
