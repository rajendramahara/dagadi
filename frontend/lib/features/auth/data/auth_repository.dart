import '../../../core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  AuthRepository(this._client);
  final ApiClient _client;

  /// Returns the dev OTP code if running against a dev-mode backend
  /// (so the UI can auto-fill it), or null in production.
  Future<String?> requestOtp(String phone, {String name = ''}) async {
    final res = await _client
        .post('/api/v1/auth/otp/request', data: {'phone': phone, 'name': name});
    final data = res.data['data'] as Map<String, dynamic>;
    return data['dev_otp'] as String?;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
    required String role,
    String? name,
  }) async {
    final res = await _client.post('/api/v1/auth/otp/verify', data: {
      'phone': phone,
      'code': code,
      'role': role,
      'name': name ?? '',
    });
    final data = res.data['data'] as Map<String, dynamic>;
    await _client.saveTokens(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
    await (await SharedPreferences.getInstance())
        .setString('dagadi_session_role', data['user']['role'] as String);
    return data['user'] as Map<String, dynamic>;
  }

  Future<bool> checkOtp({required String phone, required String code}) async {
    final res = await _client.post('/api/v1/auth/otp/check', data: {
      'phone': phone,
      'code': code,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    return data['existing_account'] as bool;
  }

  Future<Map<String, dynamic>> switchRole(String role) async {
    final res = await _client.post('/api/v1/auth/role', data: {'role': role});
    final data = res.data['data'] as Map<String, dynamic>;
    await _client.saveTokens(
        access: data['access_token'] as String,
        refresh: data['refresh_token'] as String);
    await (await SharedPreferences.getInstance())
        .setString('dagadi_session_role', data['user']['role'] as String);
    return data['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateName(String name) async {
    final res =
        await _client.patch('/api/v1/auth/profile', data: {'name': name});
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<String?> restoreRole() async {
    if (!await _client.isLoggedIn) return null;
    return (await SharedPreferences.getInstance())
        .getString('dagadi_session_role');
  }

  Future<void> logout() async {
    await _client.clearTokens();
    await (await SharedPreferences.getInstance()).remove('dagadi_session_role');
  }
}
