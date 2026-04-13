import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';

class BrowseShell extends ConsumerWidget {
  const BrowseShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: Colors.grey,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/browse');
            case 1:
              context.push('/login');
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.work_outline),
            activeIcon: const Icon(Icons.work),
            label: strings['jobs'] ?? 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.login),
            activeIcon: const Icon(Icons.login),
            label: strings['login'] ?? 'Login',
          ),
        ],
      ),
    );
  }
}
