import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/core/utils/tap_to_call.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/repositories/api/api_application_repository.dart';

class ApplicantTile extends ConsumerWidget {
  const ApplicantTile({
    super.key,
    required this.applicant,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final ApplicantModel applicant;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final isPending = applicant.status == 'pending';
    final ratingText = applicant.ratingAvg != null
        ? applicant.ratingAvg!.toStringAsFixed(1)
        : (strings['no_rating'] ?? 'New');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    applicant.displayName.isNotEmpty
                        ? applicant.displayName.characters.first.toUpperCase()
                        : '?',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        applicant.displayName,
                        style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(ratingText, style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                if (applicant.phoneNumber != null)
                  IconButton(
                    key: ValueKey('applicant-call-${applicant.applicationId}'),
                    icon: const Icon(Icons.phone, color: AppTheme.accent),
                    tooltip: strings['call_worker'] ?? 'Call',
                    onPressed: () => dialPhone(applicant.phoneNumber!),
                  ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: ValueKey('applicant-reject-${applicant.applicationId}'),
                      onPressed: busy ? null : onReject,
                      child: Text(strings['reject'] ?? 'Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      key: ValueKey('applicant-accept-${applicant.applicationId}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent, foregroundColor: Colors.white,
                      ),
                      onPressed: busy ? null : onAccept,
                      child: Text(strings['accept'] ?? 'Accept'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _statusLabel(strings, applicant.status),
                  style: GoogleFonts.nunito(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(Map<String, String> strings, String status) => switch (status) {
    'accepted'  => strings['accepted_label'] ?? 'Accepted',
    'rejected'  => strings['rejected_label'] ?? 'Rejected',
    'withdrawn' => strings['withdrawn_label'] ?? 'Withdrawn',
    _           => strings['pending_label'] ?? 'Pending',
  };
}
