import '../../../core/network/api_client.dart';

class AdminRepository {
  AdminRepository(this._client);
  final ApiClient _client;

  Future<void> login(String username, String password) async {
    final res = await _client.post('/api/v1/admin/login', data: {
      'username': username,
      'password': password,
    });
    final token = res.data['data']['access_token'] as String;
    // Admin uses the same secure-storage-backed token slot as passenger/driver;
    // a real multi-role device (admin panel is typically desktop/web-only)
    // would keep this in its own storage key instead.
    await _client.saveTokens(access: token, refresh: token);
  }

  Future<Map<String, dynamic>> dashboard() async {
    final res = await _client.get('/api/v1/admin/dashboard');
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> updateCredentials({
    required String currentUsername,
    required String newUsername,
    required String newPassword,
  }) async {
    await _client.patch('/api/v1/admin/credentials', data: {
      'current_username': currentUsername,
      'new_username': newUsername,
      'new_password': newPassword,
    });
  }

  Future<void> setUserActive({required String userId, required bool isActive}) =>
      _client.patch('/api/v1/admin/users/$userId/status', data: {'is_active': isActive});

  Future<Map<String, dynamic>> userDetails(String userId, String period) async {
    final res = await _client.get('/api/v1/admin/users/$userId/details', query: {'period': period});
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> fleets() async { final res = await _client.get('/api/v1/admin/fleets'); return (res.data['data'] as List?) ?? []; }
}
