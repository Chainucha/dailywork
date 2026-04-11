import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';

class StatusBadge extends StatelessWidget {
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

  String get _label {
    switch (status) {
      case JobStatus.open:
        return 'Open';
      case JobStatus.assigned:
        return 'Assigned';
      case JobStatus.inProgress:
        return 'In Progress';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
