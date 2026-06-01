import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailywork/providers/language_provider.dart';

/// Color-coded badge for an application status
/// (pending | accepted | rejected | withdrawn). Distinct from [StatusBadge],
/// which models the five *job* statuses.
class ApplicationStatusBadge extends ConsumerWidget {
  final String status;
  const ApplicationStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    late final Color color;
    late final String label;
    switch (status) {
      case 'accepted':
        color = const Color(0xFF388E3C); // green
        label = strings['accepted_label'] ?? 'Accepted';
      case 'pending':
        color = const Color(0xFFF57C00); // amber/orange
        label = strings['pending_label'] ?? 'Pending';
      case 'rejected':
        color = Colors.grey;
        label = strings['rejected_label'] ?? 'Rejected';
      case 'withdrawn':
        color = Colors.grey;
        label = strings['withdrawn_label'] ?? 'Withdrawn';
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
