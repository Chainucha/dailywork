import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/user_model.dart';
import 'package:dailywork/providers/auth_provider.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/screens/shared/widgets/language_toggle_button.dart';

class RoleSelectScreen extends ConsumerWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          LanguageToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primary,
              Color(0xFF0A2F6E),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo
                  const Icon(
                    Icons.work_outline,
                    size: 72,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),

                  // App name
                  Text(
                    'DailyWork',
                    style: GoogleFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    'Find work. Hire workers.',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Worker card
                  _RoleCard(
                    icon: Icons.construction,
                    title: strings['worker'] ?? '',
                    subtitle: 'Find daily wage work near you',
                    onTap: () {
                      ref
                          .read(authProvider.notifier)
                          .selectRole(UserRole.worker);
                      context.go('/worker/home');
                    },
                  ),
                  const SizedBox(height: 16),

                  // Employer card
                  _RoleCard(
                    icon: Icons.business,
                    title: strings['employer'] ?? '',
                    subtitle: 'Post jobs and hire workers',
                    onTap: () {
                      ref
                          .read(authProvider.notifier)
                          .selectRole(UserRole.employer);
                      context.go('/employer/home');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Icon in amber circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing arrow
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.primary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
