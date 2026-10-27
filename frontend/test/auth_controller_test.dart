import 'package:dagadi/core/network/api_client.dart';
import 'package:dagadi/features/auth/data/auth_repository.dart';
import 'package:dagadi/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(ApiClient(baseUrl: 'http://localhost'));

  String? lastPhone;
  String? lastCode;
  String? lastRole;
  String? lastName;
  String? otpToReturn;

  @override
  Future<String?> requestOtp(String phone, {String name = ''}) async {
    lastPhone = phone;
    return otpToReturn;
  }

  @override
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
    required String role,
    String? name,
  }) async {
    lastPhone = phone;
    lastCode = code;
    lastRole = role;
    lastName = name;
    return {'name': 'Test User'};
  }
}

void main() {
  test('dev login verifies the development OTP and signs in with the selected role', () async {
    final repo = FakeAuthRepository();
    repo.otpToReturn = '123456';
    final controller = AuthController(repo);

    final ok = await controller.devLogin(role: 'passenger', phone: '+919999999999', name: 'Passenger User');

    expect(ok, isTrue);
    expect(repo.lastPhone, '+919999999999');
    expect(repo.lastCode, '123456');
    expect(repo.lastRole, 'passenger');
    expect(repo.lastName, 'Passenger User');
    expect(controller.state.status, AuthStatus.success);
  });
}
