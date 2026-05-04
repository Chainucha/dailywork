import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';

class EmployerShell extends ConsumerWidget {
  const EmployerShell({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.contains('/employer/my-jobs')) return 1;
    if (loc.contains('/employer/profile')) return 2;
    return 0;
  }

  bool _showFab(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    return loc.endsWith('/employer/home') || loc.endsWith('/employer/my-jobs');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      floatingActionButton: _showFab(context)
          ? FloatingActionButton(
              backgroundColor: AppTheme.accent,
              onPressed: () => context.push('/employer/jobs/new'),
              tooltip: strings['post_job'] ?? 'Post Job',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: Colors.grey,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w500, fontSize: 12),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          switch (index) {
            case 0: context.go('/employer/home');
            case 1: context.go('/employer/my-jobs');
            case 2: context.go('/employer/profile');
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: strings['home'] ?? 'Home',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.work_outline),
            activeIcon: const Icon(Icons.work),
            label: strings['tab_my_jobs'] ?? 'My Jobs',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: strings['profile'] ?? 'Profile',
          ),
        ],
      ),
    );
  }
}
