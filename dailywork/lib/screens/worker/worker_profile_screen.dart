import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/auth_provider.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/repositories/api/api_review_repository.dart';
import 'package:dailywork/screens/auth/name_entry_screen.dart';
import 'package:dailywork/screens/shared/widgets/language_toggle_button.dart';

class WorkerProfileScreen extends ConsumerWidget {
  const WorkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final user = ref.watch(authProvider).user;

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
                _ProfileHeader(
                  displayName: user.displayName,
                  ratingAvg: user.workerProfile?.ratingAvg ?? 0,
                  jobsCompleted: user.workerProfile?.jobsCompleted ?? 0,
                  totalReviews: user.workerProfile?.totalReviews ?? 0,
                  strings: strings,
                  onEditName: () => context.push(
                    '/name-entry',
                    extra: NameEntryArgs(
                      mode: NameEntryMode.edit,
                      initialName: user.displayName,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Skills section
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings['core_skills'] ?? 'Core Skills',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (user.workerProfile?.skills ?? [])
                              .map(
                                (skill) => Chip(
                                  label: Text(skill),
                                  backgroundColor:
                                      AppTheme.primary.withValues(alpha: 0.1),
                                  labelStyle: GoogleFonts.nunito(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  side: BorderSide.none,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Stats section — Reviews + Jobs Done
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _StatRow(
                          label: strings['reviews'] ?? 'Reviews',
                          value: '${user.workerProfile?.totalReviews ?? 0}',
                        ),
                        const Divider(height: 20),
                        _StatRow(
                          label: strings['jobs_completed'] ?? 'Jobs Done',
                          value: '${user.workerProfile?.jobsCompleted ?? 0}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Reviews section — live from backend
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings['recent_reviews'] ?? 'Recent Reviews',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ReviewsList(userId: user.id),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _LogoutTile(strings: strings),
              ],
            ),
    );
  }
}

class _LogoutTile extends ConsumerWidget {
  const _LogoutTile({required this.strings});
  final Map<String, String> strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: const Icon(Icons.logout, color: Colors.redAccent),
        title: Text(
          strings['logout'] ?? 'Log out',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.redAccent,
          ),
        ),
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(strings['logout'] ?? 'Log out'),
              content: Text(
                strings['logout_confirm'] ??
                    'Are you sure you want to log out?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(strings['cancel'] ?? 'Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(
                    strings['logout'] ?? 'Log out',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          );
          if (confirm != true) return;
          await ref.read(authProvider.notifier).logout();
        },
      ),
    );
  }
}

class _ReviewsList extends ConsumerWidget {
  const _ReviewsList({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPage = ref.watch(userReviewsProvider(userId));

    return asyncPage.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Couldn\u2019t load reviews',
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.invalidate(userReviewsProvider(userId)),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return Text(
            'No reviews yet',
            style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600]),
          );
        }
        return Column(
          children: page.items
              .asMap()
              .entries
              .map((entry) => _ReviewItem(
                    review: entry.value,
                    isLast: entry.key == page.items.length - 1,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.ratingAvg,
    required this.jobsCompleted,
    required this.totalReviews,
    required this.strings,
    required this.onEditName,
  });

  final String displayName;
  final double ratingAvg;
  final int jobsCompleted;
  final int totalReviews;
  final Map<String, String> strings;
  final VoidCallback onEditName;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Edit name',
                icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                onPressed: onEditName,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              strings['worker'] ?? 'Worker',
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
                value: '$jobsCompleted',
                label: strings['jobs_completed'] ?? 'Jobs Done',
              ),
              _HeaderStat(
                value: '$totalReviews',
                label: strings['reviews'] ?? 'Reviews',
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
          style: GoogleFonts.nunito(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review, required this.isLast});
  final Review review;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('yyyy-MM-dd').format(review.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    color: AppTheme.accent,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.reviewerDisplayName,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                dateLabel,
                style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.comment!,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
          if (!isLast) const Divider(height: 16),
        ],
      ),
    );
  }
}
