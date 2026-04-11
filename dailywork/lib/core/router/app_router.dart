import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dailywork/screens/auth/role_select_screen.dart';
import 'package:dailywork/screens/worker/worker_shell.dart';
import 'package:dailywork/screens/worker/worker_home_screen.dart';
import 'package:dailywork/screens/worker/worker_job_detail_screen.dart';
import 'package:dailywork/screens/worker/worker_profile_screen.dart';
import 'package:dailywork/screens/employer/employer_shell.dart';
import 'package:dailywork/screens/employer/employer_home_screen.dart';
import 'package:dailywork/screens/employer/employer_job_detail_screen.dart';
import 'package:dailywork/screens/employer/employer_profile_screen.dart';

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
    // Root — role selection
    GoRoute(
      path: '/',
      builder: (context, state) => const RoleSelectScreen(),
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
