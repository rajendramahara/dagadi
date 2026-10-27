import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../router/app_router.dart';

/// Thin wrapper around Dio. All feature repositories talk to the backend
/// through this single client so base URL, auth headers, retry/refresh,
/// and error normalization live in exactly one place.
class ApiClient {
  ApiClient({required this.baseUrl})
      : _dio = Dio(BaseOptions(baseUrl: baseUrl)) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _read(_accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            error.requestOptions.extra['skipAuthRefresh'] != true) {
          final refreshed = await _refreshOnce();
          if (refreshed) {
            final retryReq = error.requestOptions;
            final token = await _read(_accessTokenKey);
            retryReq.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch(retryReq);
              return handler.resolve(response);
            } catch (retryError) {
              if (retryError is DioException &&
                  retryError.response?.statusCode == 401) {
                await _endSession();
              }
              // fall through to original error if retry also fails
            }
          }
        }
        handler.next(error);
      },
    ));
  }

  final String baseUrl;
  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Future<bool>? _refreshInFlight;

  static const _accessTokenKey = 'dagadi_access_token';
  static const _refreshTokenKey = 'dagadi_refresh_token';

  Future<bool> _refreshOnce() {
    final active = _refreshInFlight;
    if (active != null) return active;
    final future = _tryRefresh();
    _refreshInFlight = future;
    future.whenComplete(() => _refreshInFlight = null);
    return future;
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await _read(_refreshTokenKey);
    if (refreshToken == null) {
      await _endSession();
      return false;
    }
    try {
      final response = await _dio.post('/api/v1/auth/refresh',
          data: {'refresh_token': refreshToken},
          options: Options(extra: {'skipAuthRefresh': true}));
      final newAccess = response.data['data']['access_token'] as String?;
      if (newAccess == null) return false;
      await _write(_accessTokenKey, newAccess);
      return true;
    } catch (_) {
      await _endSession();
      return false;
    }
  }

  Future<void> _endSession() async {
    await clearTokens();
    // The visible route can outlive a cleared browser token after a rebuild.
    // Move to the sign-in screen instead of leaving driver pages full of 401s.
    appRouter.go('/login');
  }

  Future<void> saveTokens(
      {required String access, required String refresh}) async {
    await _write(_accessTokenKey, access);
    await _write(_refreshTokenKey, refresh);
  }

  Future<void> clearTokens() async {
    await _delete(_accessTokenKey);
    await _delete(_refreshTokenKey);
  }

  Future<bool> get isLoggedIn async => (await _read(_accessTokenKey)) != null;

  Future<String?> _read(String key) async {
    if (kIsWeb) return (await SharedPreferences.getInstance()).getString(key);
    return _storage.read(key: key);
  }

  Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).setString(key, value);
      return;
    }
    await _storage.write(key: key, value: value);
  }

  Future<void> _delete(String key) async {
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).remove(key);
      return;
    }
    await _storage.delete(key: key);
  }

  Dio get raw => _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.get<T>(path, queryParameters: query);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path, {dynamic data}) =>
      _dio.delete<T>(path, data: data);
}
