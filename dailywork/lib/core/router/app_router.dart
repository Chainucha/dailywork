import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dailywork/screens/auth/role_select_screen.dart';

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

// Worker screens
class WorkerHomeScreenPlaceholder extends StatelessWidget {
  const WorkerHomeScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScreen(label: 'Worker Home');
}

class WorkerJobDetailScreenPlaceholder extends StatelessWidget {
  const WorkerJobDetailScreenPlaceholder({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) =>
      _PlaceholderScreen(label: 'Worker Job Detail — $jobId');
}

class WorkerProfileScreenPlaceholder extends StatelessWidget {
  const WorkerProfileScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScreen(label: 'Worker Profile');
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

class WorkerShellPlaceholder extends StatelessWidget {
  const WorkerShellPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const _PlaceholderScreen(label: 'Worker Shell');
}

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
    GoRoute(
      path: '/worker',
      builder: (context, state) => const WorkerShellPlaceholder(),
      routes: [
        GoRoute(
          path: 'home',
          builder: (context, state) => const WorkerHomeScreenPlaceholder(),
        ),
        GoRoute(
          path: 'jobs/:id',
          builder: (context, state) => WorkerJobDetailScreenPlaceholder(
            jobId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(
          path: 'profile',
          builder: (context, state) => const WorkerProfileScreenPlaceholder(),
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
