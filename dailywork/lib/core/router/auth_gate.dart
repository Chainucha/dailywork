import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dailywork/providers/auth_provider.dart';

/// Checks if the user is authenticated. If not, saves [intendedPath] and
/// navigates to the login screen. Returns `true` if authenticated.
///
/// Call this at the start of any action that requires authentication:
/// ```dart
/// onPressed: () {
///   if (!requireAuth(ref, context, intendedPath: '/worker/jobs/123')) return;
///   // proceed with authenticated action
/// }
/// ```
bool requireAuth(WidgetRef ref, BuildContext context,
    {required String intendedPath}) {
  final auth = ref.read(authProvider);
  if (auth.status == AuthStatus.authenticated) return true;
  ref.read(authProvider.notifier).setPendingRedirect(intendedPath);
  if (!context.mounted) return false;
  context.go('/login');
  return false;
}
