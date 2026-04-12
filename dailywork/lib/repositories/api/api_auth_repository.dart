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

  /// Returns the user's user_type ('worker' or 'employer').
  /// [userType] is only required for first-time users.
  /// Saves tokens to secure storage on success.
  Future<String> verifyOtp({
    required String phone,
    required String token,
    String? userType,
  }) async {
    final body = {
      'phone': phone,
      'token': token,
      'user_type': ?userType,
    };
    final response = await _dio.post<Map<String, dynamic>>('/auth/verify-otp', data: body);
    final data = response.data!;
    await _tokenStorage.saveTokens(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
    return data['user_type'] as String;
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
