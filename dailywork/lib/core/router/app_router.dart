import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dailywork/models/user_model.dart';
import 'package:dailywork/providers/auth_provider.dart';
import 'package:dailywork/screens/auth/splash_screen.dart';
import 'package:dailywork/screens/auth/phone_login_screen.dart';
import 'package:dailywork/screens/auth/otp_verify_screen.dart';
import 'package:dailywork/screens/worker/worker_shell.dart';
import 'package:dailywork/screens/worker/worker_home_screen.dart';
import 'package:dailywork/screens/worker/worker_job_detail_screen.dart';
import 'package:dailywork/screens/worker/worker_profile_screen.dart';
import 'package:dailywork/screens/employer/employer_shell.dart';
import 'package:dailywork/screens/employer/employer_home_screen.dart';
import 'package:dailywork/screens/employer/employer_job_detail_screen.dart';
import 'package:dailywork/screens/employer/employer_profile_screen.dart';

// ---------------------------------------------------------------------------
// Auth → Router bridge
// ---------------------------------------------------------------------------

/// A minimal ChangeNotifier that the GoRouter can watch for auth state changes.
class _AuthListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

const _authRoutes = {'/login', '/verify-otp'};

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable();

  // Keep listenable in sync with auth state changes.
  ref.listen<AuthState>(authProvider, (_, _) => listenable.notify());
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.uri.path;

      switch (auth.status) {
        case AuthStatus.unknown:
          // Still bootstrapping — keep user on splash screen.
          return loc == '/' ? null : '/';

        case AuthStatus.unauthenticated:
          // Must be on an auth route; send everyone else to login.
          return _authRoutes.contains(loc) ? null : '/login';

        case AuthStatus.authenticated:
          // Redirect away from auth/splash routes to the correct home.
          if (loc == '/' || _authRoutes.contains(loc)) {
            return auth.user!.role == UserRole.worker
                ? '/worker/home'
                : '/employer/home';
          }
          return null;
      }
    },
    routes: [
      // Splash — shown while bootstrap() runs
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth flow
      GoRoute(
        path: '/login',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) =>
            OtpVerifyScreen(phone: state.extra as String),
      ),

      // Worker section
      ShellRoute(
        builder: (context, state, child) => WorkerShell(child: child),
        routes: [
          GoRoute(
            path: '/worker/home',
            builder: (context, state) => const WorkerHomeScreen(),
          ),
          GoRoute(
            path: '/worker/jobs/:id',
            builder: (context, state) => WorkerJobDetailScreen(
              jobId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/worker/profile',
            builder: (context, state) => const WorkerProfileScreen(),
          ),
        ],
      ),

      // Employer section
      ShellRoute(
        builder: (context, state, child) => EmployerShell(child: child),
        routes: [
          GoRoute(
            path: '/employer/home',
            builder: (context, state) => const EmployerHomeScreen(),
          ),
          GoRoute(
            path: '/employer/jobs/:id',
            builder: (context, state) => EmployerJobDetailScreen(
              jobId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/employer/profile',
            builder: (context, state) => const EmployerProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
