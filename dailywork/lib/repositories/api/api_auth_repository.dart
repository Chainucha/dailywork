import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/core/auth/token_storage.dart';
import 'package:dailywork/core/network/api_client.dart';

class ApiAuthRepository {
  final Dio _dio;
  final TokenStorage _tokenStorage;

  ApiAuthRepository(this._dio, this._tokenStorage);

  Future<void> sendOtp(String phone) async {
    await _dio.post('/auth/send-otp', data: {'phone': phone});
  }

  /// Verifies OTP. Returns `isNewUser: true` when the user has no profile yet.
  /// Always saves tokens to secure storage on success.
  Future<bool> verifyOtp({required String phone, required String token}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/verify-otp',
      data: {'phone': phone, 'token': token},
    );
    final data = response.data!;
    await _tokenStorage.saveTokens(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
    return data['is_new_user'] as bool? ?? false;
  }

  Future<void> setupProfile(String userType) async {
    await _dio.post('/auth/setup-profile', data: {'user_type': userType});
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } finally {
      await _tokenStorage.clear();
    }
  }
}

final apiAuthRepositoryProvider = Provider<ApiAuthRepository>((ref) {
  return ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});
