import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

enum AuthStatus { idle, sendingOtp, verifying, success, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.idle,
    this.phone = '',
    this.role = 'passenger',
    this.devOtp,
    this.errorMessage,
    this.userName,
    this.pendingCode,
  });

  final AuthStatus status;
  final String phone;
  final String role;
  final String? devOtp;
  final String? errorMessage;
  final String? userName;
  final String? pendingCode;

  AuthState copyWith({
    AuthStatus? status,
    String? phone,
    String? role,
    String? devOtp,
    String? errorMessage,
    String? userName,
    String? pendingCode,
  }) {
    return AuthState(
      status: status ?? this.status,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      devOtp: devOtp ?? this.devOtp,
      errorMessage: errorMessage,
      userName: userName ?? this.userName,
      pendingCode: pendingCode ?? this.pendingCode,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(const AuthState());
  final AuthRepository _repo;

  void setRole(String role) => state = state.copyWith(role: role);

  Future<bool> updateDisplayName(String name) async {
    try {
      final user = await _repo.updateName(name);
      state = state.copyWith(userName: user['name'] as String?);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<void> sendOtp(String phone, {required String name}) async {
    state = state.copyWith(
        status: AuthStatus.sendingOtp,
        phone: phone,
        userName: name,
        errorMessage: null);
    try {
      final devOtp = await _repo.requestOtp(phone, name: name);
      state = state.copyWith(status: AuthStatus.idle, devOtp: devOtp);
    } catch (e) {
      state =
          state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<bool> verifyOtp(String code, {String? name}) async {
    state = state.copyWith(status: AuthStatus.verifying, errorMessage: null);
    try {
      final user = await _repo.verifyOtp(
          phone: state.phone, code: code, role: state.role, name: name);
      state = state.copyWith(
          status: AuthStatus.success,
          userName: user['name'] as String?,
          role: user['role'] as String?);
      return true;
    } catch (e) {
      state =
          state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool?> checkOtp(String code) async {
    state = state.copyWith(status: AuthStatus.verifying, errorMessage: null);
    try {
      final existing = await _repo.checkOtp(phone: state.phone, code: code);
      state = state.copyWith(status: AuthStatus.idle, pendingCode: code);
      return existing;
    } catch (e) {
      state =
          state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
      return null;
    }
  }

  Future<bool> switchRole(String role) async {
    state = state.copyWith(status: AuthStatus.verifying, errorMessage: null);
    try {
      final user = await _repo.switchRole(role);
      state = state.copyWith(
          status: AuthStatus.success,
          role: user['role'] as String?,
          userName: user['name'] as String?);
      return true;
    } catch (e) {
      state =
          state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> devLogin(
      {required String role, required String phone, String? name}) async {
    state = state.copyWith(
        status: AuthStatus.verifying,
        phone: phone,
        role: role,
        errorMessage: null);
    try {
      // Obtain the development OTP from the backend and verify it normally.
      // This keeps the local shortcut convenient while still saving real JWTs,
      // which the passenger and driver API calls require.
      final code = await _repo.requestOtp(phone, name: name ?? '');
      if (code == null) {
        throw StateError('Development OTP is unavailable for this server.');
      }
      final user = await _repo.verifyOtp(
          phone: phone, code: code, role: role, name: name);
      state = state.copyWith(
          status: AuthStatus.success,
          userName: user['name'] as String?,
          role: role);
      return true;
    } catch (e) {
      state =
          state.copyWith(status: AuthStatus.error, errorMessage: e.toString());
      return false;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
