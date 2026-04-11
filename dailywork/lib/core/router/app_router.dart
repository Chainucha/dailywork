import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dailywork/screens/auth/role_select_screen.dart';
import 'package:dailywork/screens/worker/worker_shell.dart';
import 'package:dailywork/screens/worker/worker_home_screen.dart';
import 'package:dailywork/screens/worker/worker_job_detail_screen.dart';
import 'package:dailywork/screens/worker/worker_profile_screen.dart';

// ---------------------------------------------------------------------------
// Placeholder screens — will be replaced when real screen files are created.
// ---------------------------------------------------------------------------

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

// Employer screens
class EmployerHomeScreenPlaceholder extends StatelessWidget {
  const EmployerHomeScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScreen(label: 'Employer Home');
}

class EmployerJobDetailScreenPlaceholder extends StatelessWidget {
  const EmployerJobDetailScreenPlaceholder({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) =>
      _PlaceholderScreen(label: 'Employer Job Detail — $jobId');
}

class EmployerProfileScreenPlaceholder extends StatelessWidget {
  const EmployerProfileScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScreen(label: 'Employer Profile');
}

// ---------------------------------------------------------------------------
// Shell placeholders (bottom-nav wrappers — flat GoRoute for now)
// ---------------------------------------------------------------------------

class EmployerShellPlaceholder extends StatelessWidget {
  const EmployerShellPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScreen(label: 'Employer Shell');
}

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
    GoRoute(
      path: '/employer',
      builder: (context, state) => const EmployerShellPlaceholder(),
      routes: [
        GoRoute(
          path: 'home',
          builder: (context, state) => const EmployerHomeScreenPlaceholder(),
        ),
        GoRoute(
          path: 'jobs/:id',
          builder: (context, state) => EmployerJobDetailScreenPlaceholder(
            jobId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(
          path: 'profile',
          builder: (context, state) => const EmployerProfileScreenPlaceholder(),
        ),
      ],
    ),
  ],
  );
});
