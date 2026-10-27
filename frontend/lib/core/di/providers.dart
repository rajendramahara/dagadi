import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Base URL is environment-driven so the same build can point at a local
/// dev backend or a production API without code changes.
/// Override at build time with: --dart-define=API_BASE_URL=https://api.dagadi.app
const String _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: _apiBaseUrl);
});
