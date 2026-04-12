import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/core/auth/token_storage.dart';
import 'package:dailywork/models/user_model.dart';
import 'package:dailywork/repositories/api/api_auth_repository.dart';
import 'package:dailywork/repositories/api/api_user_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final UserModel? user;
  final AuthStatus status;

  const AuthState({this.user, required this.status});

  AuthState copyWith({UserModel? user, AuthStatus? status}) => AuthState(
        user: user ?? this.user,
        status: status ?? this.status,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiAuthRepository _authRepo;
  final ApiUserRepository _userRepo;
  final TokenStorage _tokenStorage;

  AuthNotifier(this._authRepo, this._userRepo, this._tokenStorage)
      : super(const AuthState(status: AuthStatus.unknown));

  /// Called on app start. Reads stored token; if valid, loads the user profile.
  Future<void> bootstrap() async {
    final token = await _tokenStorage.readAccess();
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _userRepo.getMe();
      state = AuthState(user: user, status: AuthStatus.authenticated);
    } catch (_) {
      await _tokenStorage.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Sends OTP to [phone]. Throws [ApiException] on failure.
  Future<void> sendOtp(String phone) async {
    await _authRepo.sendOtp(phone);
  }

  /// Verifies OTP and loads the user profile.
  /// [userType] is only needed for brand-new users.
  /// Returns the user's role string ('worker' or 'employer').
  Future<String> verifyOtp({
    required String phone,
    required String token,
    String? userType,
  }) async {
    final roleStr = await _authRepo.verifyOtp(
      phone: phone,
      token: token,
      userType: userType,
    );
    final user = await _userRepo.getMe();
    state = AuthState(user: user, status: AuthStatus.authenticated);
    return roleStr;
  }

  Future<void> logout() async {
    await _authRepo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(apiAuthRepositoryProvider),
    ref.watch(apiUserRepositoryProvider),
    ref.watch(tokenStorageProvider),
  );
});
