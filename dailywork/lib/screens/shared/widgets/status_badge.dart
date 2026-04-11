import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/language_provider.dart';

class StatusBadge extends ConsumerWidget {
  final JobStatus status;

  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case JobStatus.open:
        return AppTheme.statusOpen;
      case JobStatus.assigned:
        return AppTheme.statusAssigned;
      case JobStatus.inProgress:
        return AppTheme.statusInProgress;
      case JobStatus.completed:
        return AppTheme.statusCompleted;
      case JobStatus.cancelled:
        return AppTheme.statusCancelled;
    }
  }

  String _label(Map<String, String> strings) {
    switch (status) {
      case JobStatus.open:
        return strings['open'] ?? 'Open';
      case JobStatus.assigned:
        return strings['assigned'] ?? 'Assigned';
      case JobStatus.inProgress:
        return strings['in_progress'] ?? 'In Progress';
      case JobStatus.completed:
        return strings['completed'] ?? 'Completed';
      case JobStatus.cancelled:
        return strings['cancelled'] ?? 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label(strings),
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
