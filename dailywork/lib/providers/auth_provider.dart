import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/mock_users.dart';

class AuthNotifier extends StateNotifier<UserModel?> {
  AuthNotifier() : super(null);

  void selectRole(UserRole role) {
    if (role == UserRole.worker) {
      state = MockUsers.workerUser;
    } else {
      state = MockUsers.employerUser;
    }
  }

  void logout() {
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier();
});
