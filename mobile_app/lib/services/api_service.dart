// lib/services/api_service.dart
//
// SmartPulse v2 — API Service
// Talks to the Flask backend at BASE_URL.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prediction_result.dart';

class ApiService {
  static const String _configuredBaseUrl =
      String.fromEnvironment('SMARTPULSE_API_URL', defaultValue: '');
  static const String _cachedBaseUrlKey = 'smartpulse_cached_backend_url';
  static const Duration _probeTimeout = Duration(milliseconds: 900);
  static const Duration _requestTimeout = Duration(seconds: 8);

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

    final cachedUrl = await _loadCachedBaseUrl();
    if (cachedUrl != null && await _isBackendReachable(cachedUrl)) {
      _baseUrl = cachedUrl;
      return;
    }

    await _discoverBackendUrl(includeSubnetScan: false);
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

  static Future<String?> _loadCachedBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cachedBaseUrlKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCachedBaseUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedBaseUrlKey, url);
    } catch (_) {
      // Best-effort cache only.
    }
  }

  static Future<void> _rememberWorkingUrl(String url) async {
    _baseUrl = url;
    await _saveCachedBaseUrl(url);
  }

  static Future<bool> _isBackendReachable(String url) async {
    try {
      final response =
          await http.get(Uri.parse('$url/')).timeout(_probeTimeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _probeCandidate(String url) async {
    final reachable = await _isBackendReachable(url);
    return reachable ? url : null;
  }

  static Future<String?> _findFirstReachable(
    List<String> urls, {
    int batchSize = 12,
  }) async {
    final uniqueUrls = <String>{};
    final candidates = <String>[];

    for (final url in urls) {
      final normalized = url.trim();
      if (normalized.isEmpty || !uniqueUrls.add(normalized)) {
        continue;
      }
      candidates.add(normalized);
    }

    for (var i = 0; i < candidates.length; i += batchSize) {
      final batch = candidates.skip(i).take(batchSize);
      final results = await Future.wait(batch.map(_probeCandidate));
      for (final result in results) {
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  static Future<List<String>> _buildQuickCandidateUrls({
    List<String> preferredUrls = const [],
    Set<String> excludeUrls = const {},
  }) async {
    final gatewayUrls = await _getPossibleGatewayUrls();
    final cachedUrl = await _loadCachedBaseUrl();

    final urls = <String>[
      ...preferredUrls,
      if (cachedUrl != null) cachedUrl,
      _baseUrl,
      if (_configuredBaseUrl.isNotEmpty) _configuredBaseUrl,
      ...gatewayUrls,
      'http://127.0.0.1:3000',
      'http://localhost:3000',
      'http://10.0.2.2:3000',
      'http://10.0.0.2:3000',
      'http://127.0.0.1:5000',
      'http://localhost:5000',
      'http://10.0.0.2:5000',
      'http://10.0.2.2:5000',
      'http://192.168.1.100:5000',
      'http://192.168.0.100:5000',
      'http://192.168.1.101:5000',
      'http://192.168.0.101:5000',
      'http://10.0.3.191:5000',
      'http://10.0.12.163:5000',
      'http://172.16.0.1:5000',
      'http://169.254.0.1:5000',
    ];

    return urls
        .where((url) => url.isNotEmpty && !excludeUrls.contains(url))
        .toList();
  }

  static List<String> _buildSubnetScanUrls(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      return const [];
    }

    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    final selfHost = int.tryParse(parts[3]);
    final urls = <String>[];

    for (var host = 2; host <= 254; host++) {
      if (host == selfHost) {
        continue;
      }
      urls.add('http://$prefix.$host:5000');
      urls.add('http://$prefix.$host:3000');
    }

    return urls;
  }

  static Future<List<String>> _buildSubnetCandidates({
    Set<String> excludeUrls = const {},
  }) async {
    final urls = <String>[];

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type != InternetAddressType.IPv4) {
            continue;
          }

          final ip = addr.address;
          if (!(ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.16.') ||
              ip.startsWith('172.17.') ||
              ip.startsWith('172.18.') ||
              ip.startsWith('172.19.') ||
              ip.startsWith('172.2') ||
              ip.startsWith('172.30.') ||
              ip.startsWith('172.31.'))) {
            continue;
          }

          urls.addAll(_buildSubnetScanUrls(ip));
        }
      }
    } catch (e) {
      print('⚠️ Error building subnet candidates: $e');
    }

    return urls.where((url) => !excludeUrls.contains(url)).toList();
  }

  static Future<bool> ensureBackendAvailable({
    bool includeSubnetScan = false,
    Set<String> excludeUrls = const {},
    List<String> preferredUrls = const [],
  }) async {
    if (_configuredBaseUrl.isNotEmpty &&
        !excludeUrls.contains(_configuredBaseUrl) &&
        await _isBackendReachable(_configuredBaseUrl)) {
      await _rememberWorkingUrl(_configuredBaseUrl);
      return true;
    }

    if (!excludeUrls.contains(_baseUrl) &&
        await _isBackendReachable(_baseUrl)) {
      await _rememberWorkingUrl(_baseUrl);
      return true;
    }

    final discovered = await _discoverBackendUrl(
      includeSubnetScan: includeSubnetScan,
      excludeUrls: excludeUrls,
      preferredUrls: preferredUrls,
    );
    return discovered != null;
  }

  static Future<String?> _discoverBackendUrl({
    bool includeSubnetScan = false,
    Set<String> excludeUrls = const {},
    List<String> preferredUrls = const [],
  }) async {
    final quickCandidates = await _buildQuickCandidateUrls(
      preferredUrls: preferredUrls,
      excludeUrls: excludeUrls,
    );
    final quickMatch = await _findFirstReachable(quickCandidates);
    if (quickMatch != null) {
      await _rememberWorkingUrl(quickMatch);
      return quickMatch;
    }

    if (!includeSubnetScan) {
      return null;
    }

    final subnetCandidates =
        await _buildSubnetCandidates(excludeUrls: excludeUrls);
    final subnetMatch =
        await _findFirstReachable(subnetCandidates, batchSize: 20);
    if (subnetMatch != null) {
      await _rememberWorkingUrl(subnetMatch);
      return subnetMatch;
    }

    return null;
  }

  Future<http.Response> _postWithBackendRecovery(
    String path,
    Map<String, dynamic> body,
  ) async {
    await ensureBackendAvailable(includeSubnetScan: false);

    try {
      return await http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_requestTimeout);
    } catch (error) {
      final failedUrl = _baseUrl;
      final recovered = await _discoverBackendUrl(
        includeSubnetScan: true,
        excludeUrls: {failedUrl},
      );

      if (recovered == null) {
        rethrow;
      }

      return http
          .post(
            Uri.parse('$recovered$path'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(_requestTimeout);
    }
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
      final available =
          await ensureBackendAvailable(includeSubnetScan: false) ||
              await ensureBackendAvailable(includeSubnetScan: true);
      if (!available) {
        return false;
      }

      print('🔍 Checking backend connection to: $_baseUrl');
      final response =
          await http.get(Uri.parse('$_baseUrl/')).timeout(_probeTimeout);

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
        final response =
            await _postWithBackendRecovery('/auth/register', userData);

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
    final requestBody = {
      'email': email,
      'password': password,
    };

    while (retryCount <= maxRetries) {
      try {
        final response =
            await _postWithBackendRecovery('/auth/login', requestBody);

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
