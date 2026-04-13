import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/core/auth/token_storage.dart';
import 'package:dailywork/models/user_model.dart';
import 'package:dailywork/repositories/api/api_auth_repository.dart';
import 'package:dailywork/repositories/api/api_user_repository.dart';

enum AuthStatus { unknown, unauthenticated, guest, authenticated }

class AuthState {
  final UserModel? user;
  final AuthStatus status;
  /// Path to navigate to after successful login (set by auth gate).
  final String? pendingRedirect;

  const AuthState({this.user, required this.status, this.pendingRedirect});

  AuthState copyWith({
    UserModel? user,
    AuthStatus? status,
    String? pendingRedirect,
    bool clearRedirect = false,
  }) =>
      AuthState(
        user: user ?? this.user,
        status: status ?? this.status,
        pendingRedirect:
            clearRedirect ? null : (pendingRedirect ?? this.pendingRedirect),
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
      state = const AuthState(status: AuthStatus.guest);
      return;
    }
    try {
      final user = await _userRepo.getMe();
      state = AuthState(user: user, status: AuthStatus.authenticated);
    } catch (_) {
      await _tokenStorage.clear();
      state = const AuthState(status: AuthStatus.guest);
    }
  }

  /// Transitions to guest browse mode.
  void browseAsGuest() {
    state = const AuthState(status: AuthStatus.guest);
  }

  /// Saves where the user wanted to go before being asked to log in.
  void setPendingRedirect(String path) {
    state = state.copyWith(pendingRedirect: path);
  }

  /// Clears the pending redirect and returns it (or null).
  String? consumePendingRedirect() {
    final path = state.pendingRedirect;
    if (path != null) {
      state = state.copyWith(clearRedirect: true);
    }
    return path;
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
    state = const AuthState(status: AuthStatus.guest);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(apiAuthRepositoryProvider),
    ref.watch(apiUserRepositoryProvider),
    ref.watch(tokenStorageProvider),
  );
});
