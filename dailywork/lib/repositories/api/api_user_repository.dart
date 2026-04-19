import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/models/user_model.dart';

class ApiUserRepository {
  final Dio _dio;

  ApiUserRepository(this._dio);

  /// Fetches /users/me and merges with the role-specific profile.
  Future<UserModel> getMe() async {
    final userRes = await _dio.get<Map<String, dynamic>>('/users/me');
    final userData = Map<String, dynamic>.from(userRes.data!);
    final userType = userData['user_type'] as String;

    // Fetch role-specific profile and merge fields into the user map
    if (userType == 'worker') {
      final profRes = await _dio.get<Map<String, dynamic>>('/workers/me/profile');
      userData.addAll(profRes.data!);
    } else if (userType == 'employer') {
      final profRes = await _dio.get<Map<String, dynamic>>('/employers/me/profile');
      userData.addAll(profRes.data!);
    }

    return UserModel.fromJson(userData);
  }

  Future<UserModel> updateLocation({
    required double lat,
    required double lng,
  }) async {
    await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'location_lat': lat, 'location_lng': lng},
    );
    // Re-fetch full profile to return merged model
    return getMe();
  }

  Future<UserModel> updateFcmToken(String token) async {
    await _dio.patch('/users/me', data: {'fcm_token': token});
    return getMe();
  }

  Future<UserModel> updateDisplayName(String name) async {
    await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'display_name': name},
    );
    return getMe();
  }
}

final apiUserRepositoryProvider = Provider<ApiUserRepository>((ref) {
  return ApiUserRepository(ref.watch(apiClientProvider));
});
