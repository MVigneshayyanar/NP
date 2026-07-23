import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter/foundation.dart';

/// API client configured to communicate with the Go Fiber gateway.
/// Handles JWT token injection and refresh.
class ApiClient {
  static const String _productionBaseUrl =
      'https://wholesome-gentleness-production-474b.up.railway.app/api/v1';

  static final String _baseUrl = kDebugMode
      ? (kIsWeb ? 'http://localhost:3000/api/v1' : 'http://10.0.2.2:3000/api/v1')
      : _productionBaseUrl;

  static const String _tokenKey = 'jwt_token';


  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // JWT interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Token expired — clear and redirect to login
          clearToken();
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  // ── Token Management ──

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Auth Endpoints ──

  Future<Response> register(Map<String, dynamic> data) async {
    return await _dio.post('/auth/register/', data: data);
  }

  Future<Response> login({
    required String email,
    required String password,
  }) async {
    return _dio.post('/auth/login/', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> getMe() async {
    return _dio.get('/auth/me/');
  }

  Future<Response> updateUser(String userId, Map<String, dynamic> data) async {
    return _dio.patch('/auth/user/$userId/', data: data);
  }

  // ── Profile Endpoints ──

  Future<Response> getSensoryProfile(String userId) async {
    return _dio.get('/profile/$userId/');
  }

  Future<Response> updateSensoryProfile(
      String userId, Map<String, dynamic> data) async {
    return _dio.patch('/profile/$userId/', data: data);
  }

  // ── Scan Endpoints ──

  Future<Response> analyzeEnvironment({
    required String imagePath,
    String? audioPath,
    String roomName = 'Room',
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imagePath),
      if (audioPath != null) 'audio': await MultipartFile.fromFile(audioPath),
      'room_name': roomName,
    });
    return _dio.post('/analyze-environment', data: formData);
  }

  Future<Response> getScans({String? userId}) async {
    final params = <String, dynamic>{};
    if (userId != null) params['user_id'] = userId;
    return _dio.get('/scans/', queryParameters: params);
  }

  Future<Response> getScanDetail(String scanId) async {
    return _dio.get('/scans/$scanId/');
  }

  // ── Recommendation Endpoints ──

  Future<Response> getRecommendations({String? scanId, String? userId}) async {
    final params = <String, dynamic>{};
    if (scanId != null) params['scan_id'] = scanId;
    if (userId != null) params['user_id'] = userId;
    return _dio.get('/recommendations/', queryParameters: params);
  }

  Future<Response> updateRecommendation(
      String recId, Map<String, dynamic> data) async {
    return _dio.patch('/recommendations/$recId/', data: data);
  }

  // ── Progress Endpoints ──

  Future<Response> getProgress(String userId) async {
    return _dio.get('/progress/$userId/');
  }
}
