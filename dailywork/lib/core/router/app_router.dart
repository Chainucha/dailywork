import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dailywork/models/user_model.dart';
import 'package:dailywork/providers/auth_provider.dart';
import 'package:dailywork/screens/auth/splash_screen.dart';
import 'package:dailywork/screens/auth/phone_login_screen.dart';
import 'package:dailywork/screens/auth/otp_verify_screen.dart';
import 'package:dailywork/screens/browse/browse_shell.dart';
import 'package:dailywork/screens/worker/worker_home_screen.dart';
import 'package:dailywork/screens/worker/worker_shell.dart';
import 'package:dailywork/screens/worker/worker_job_detail_screen.dart';
import 'package:dailywork/screens/worker/worker_profile_screen.dart';
import 'package:dailywork/screens/employer/employer_shell.dart';
import 'package:dailywork/screens/employer/employer_home_screen.dart';
import 'package:dailywork/screens/employer/employer_job_detail_screen.dart';
import 'package:dailywork/screens/employer/employer_profile_screen.dart';

// ---------------------------------------------------------------------------
// Auth → Router bridge
// ---------------------------------------------------------------------------

class _AuthListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}

// ---------------------------------------------------------------------------
// Route helpers
// ---------------------------------------------------------------------------

const _authRoutes = {'/login', '/verify-otp'};

bool _isBrowseRoute(String loc) =>
    loc == '/browse' || loc.startsWith('/browse/');

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable();

  ref.listen<AuthState>(authProvider, (_, next) => listenable.notify());
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.uri.path;

      switch (auth.status) {
        case AuthStatus.unknown:
          // Still bootstrapping — stay on splash.
          return loc == '/' ? null : '/';

        case AuthStatus.guest:
          // Guest can access browse routes and auth routes.
          if (loc == '/') return '/browse';
          if (_isBrowseRoute(loc) || _authRoutes.contains(loc)) return null;
          return '/browse';

        case AuthStatus.unauthenticated:
          // Actively in login flow — allow auth and browse routes.
          if (_authRoutes.contains(loc) || _isBrowseRoute(loc)) return null;
          return '/login';

        case AuthStatus.authenticated:
          // Check for pending redirect from auth gate (pure read — no state emit).
          final pending = ref.read(authProvider.notifier).consumePendingRedirect();
          if (pending != null &&
              loc != pending &&
              (loc == '/' || _authRoutes.contains(loc) || _isBrowseRoute(loc))) {
            return pending;
          }
          // Redirect away from splash, auth, and browse routes.
          if (loc == '/' || _authRoutes.contains(loc) || _isBrowseRoute(loc)) {
            final user = auth.user;
            if (user == null) return '/';
            return user.role == UserRole.worker
                ? '/worker/home'
                : '/employer/home';
          }
          return null;
      }
    },
    routes: [
      // Splash — shown while bootstrap() runs.
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

      // Guest browse — reuses existing worker screens inside BrowseShell.
      ShellRoute(
        builder: (context, state, child) => BrowseShell(child: child),
        routes: [
          GoRoute(
            path: '/browse',
            builder: (context, state) => const WorkerHomeScreen(),
          ),
          GoRoute(
            path: '/browse/jobs/:id',
            builder: (context, state) => WorkerJobDetailScreen(
              jobId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),

      // Worker section (authenticated only — router redirect enforces this).
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

      // Employer section (authenticated only).
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
