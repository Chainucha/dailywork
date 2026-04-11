import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/auth_provider.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/screens/shared/widgets/language_toggle_button.dart';

class EmployerProfileScreen extends ConsumerWidget {
  const EmployerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(
          strings['profile'] ?? 'Profile',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [LanguageToggleButton()],
      ),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Profile header
                _EmployerProfileHeader(
                  displayName: user.displayName,
                  ratingAvg: user.employerProfile?.ratingAvg ?? 0,
                  totalReviews: user.employerProfile?.totalReviews ?? 0,
                  strings: strings,
                ),
                const SizedBox(height: 12),

                // Business info card
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business Info',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BusinessInfoRow(
                          label: 'Business Name',
                          value: user.employerProfile?.businessName ?? '',
                        ),
                        const SizedBox(height: 8),
                        _BusinessInfoRow(
                          label: 'Business Type',
                          value: user.employerProfile?.businessType ?? '',
                        ),
                        const SizedBox(height: 8),
                        _BusinessInfoRow(
                          label: 'Rating',
                          value:
                              '${user.employerProfile?.ratingAvg ?? 0} \u2605',
                        ),
                        const SizedBox(height: 8),
                        _BusinessInfoRow(
                          label: 'Reviews',
                          value:
                              '${user.employerProfile?.totalReviews ?? 0} reviews',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Posted jobs section
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Posted Jobs',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.work_outline,
                              color: AppTheme.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '12 jobs posted',
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings['coming_soon'] ?? 'Coming soon',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmployerProfileHeader extends StatelessWidget {
  const _EmployerProfileHeader({
    required this.displayName,
    required this.ratingAvg,
    required this.totalReviews,
    required this.strings,
  });

  final String displayName;
  final double ratingAvg;
  final int totalReviews;
  final Map<String, String> strings;

  @override
  Widget build(BuildContext context) {
    final firstLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      color: AppTheme.primary,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.accent,
            child: Text(
              firstLetter,
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Employer',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HeaderStat(
                value: ratingAvg.toStringAsFixed(1),
                label: '\u2605 Rating',
              ),
              _HeaderStat(
                value: '$totalReviews',
                label: 'Reviews',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _BusinessInfoRow extends StatelessWidget {
  const _BusinessInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}
