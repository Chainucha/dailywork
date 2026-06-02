import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:go_router/go_router.dart';
import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/job_provider.dart';
import 'package:dailywork/providers/my_posted_jobs_provider.dart';
import 'package:dailywork/repositories/api/api_job_repository.dart';
import 'package:dailywork/screens/shared/widgets/status_badge.dart';
import 'package:dailywork/screens/shared/widgets/language_toggle_button.dart';

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class EmployerJobDetailScreen extends ConsumerStatefulWidget {
  const EmployerJobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<EmployerJobDetailScreen> createState() =>
      _EmployerJobDetailScreenState();
}

class _EmployerJobDetailScreenState
    extends ConsumerState<EmployerJobDetailScreen> {
  bool _busy = false;

  Future<void> _setStatus(String jobId, String status, String successKey) async {
    final strings = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(apiJobRepositoryProvider)
          .updateJob(jobId, {'status': status});
      ref.invalidate(jobDetailProvider(jobId));
      ref.invalidate(myPostedJobsProvider);
      messenger.showSnackBar(
          SnackBar(content: Text(strings[successKey] ?? 'Done')));
    } catch (e) {
      final apiError = ApiException.extract(e);
      messenger.showSnackBar(SnackBar(
        content: Text(apiError?.message ??
            (strings['action_failed_toast'] ?? 'Action failed — try again')),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String confirmLabel) async {
    final strings = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings['no'] ?? 'No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: jobAsync.maybeWhen(
          data: (job) => Text(
            job.title,
            style: const TextStyle(color: Colors.white),
          ),
          orElse: () => const Text(
            'Job Details',
            style: TextStyle(color: Colors.white),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: const [LanguageToggleButton()],
      ),
      body: jobAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (e, _) => const Center(
          child: Text('Failed to load job'),
        ),
        data: (job) {
          final dateStr = _formatDate(job.startDate);
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header card
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      job.title,
                                      style: GoogleFonts.nunito(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusBadge(status: job.status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                job.employerName,
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₹${job.wagePerDay.toStringAsFixed(0)}${strings['per_day'] ?? '/day'}',
                                style: GoogleFonts.nunito(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accent,
                                ),
                              ),
                              if (job.isUrgent) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    strings['urgent']?.toUpperCase() ?? 'URGENT',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _InfoTile(
                                      label: strings['start_date'] ?? 'Start Date',
                                      value: dateStr,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _InfoTile(
                                      label: strings['workers_needed'] ??
                                          'Workers Needed',
                                      value: '${job.workersNeeded}',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _InfoTile(
                                      label: 'Assigned',
                                      value: '${job.workersAssigned}',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description section
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings['description'] ?? 'Description',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                job.description ?? '',
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Applicants section
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings['applicants'] ?? 'Applicants',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => context.push(
                                  '/employer/jobs/${job.id}/applicants',
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${job.applicantCount} ${strings['applicants'] ?? 'applicants'}',
                                          style: GoogleFonts.nunito(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: AppTheme.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _bottomBar(job, strings),
            ],
          );
        },
      ),
    );
  }

  /// Status-driven actions: Start Job (assigned -> in_progress), Mark Complete
  /// (in_progress -> completed), and Edit (only before the job has started).
  Widget _bottomBar(JobModel job, Map<String, String> strings) {
    final buttons = <Widget>[];

    if (job.status == JobStatus.assigned) {
      buttons.add(_actionButton(
        label: strings['start_job'] ?? 'Start Job',
        color: AppTheme.accent,
        onPressed:
            _busy ? null : () => _setStatus(job.id, 'in_progress', 'job_started'),
      ));
    } else if (job.status == JobStatus.inProgress) {
      buttons.add(_actionButton(
        label: strings['mark_complete'] ?? 'Mark Complete',
        color: Colors.green,
        onPressed: _busy
            ? null
            : () async {
                final ok = await _confirm(
                  strings['complete_confirm_title'] ?? 'Mark job complete?',
                  strings['complete_confirm_body'] ??
                      'Confirm this job is finished. Workers can then be '
                          'reviewed. This cannot be undone.',
                  strings['mark_complete'] ?? 'Mark Complete',
                );
                if (ok) await _setStatus(job.id, 'completed', 'job_completed');
              },
      ));
    }

    // Edit only while the job has not started yet.
    if (job.status == JobStatus.open || job.status == JobStatus.assigned) {
      buttons.add(_actionButton(
        label: strings['edit_job_title'] ?? 'Edit job',
        color: AppTheme.primary,
        onPressed:
            _busy ? null : () => context.push('/employer/jobs/${job.id}/edit'),
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    final spaced = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 10));
      spaced.add(buttons[i]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: spaced),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onPressed,
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style:
                    GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 2),
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
