import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/job_provider.dart';
import 'package:dailywork/models/user_model.dart';
import 'package:dailywork/providers/auth_provider.dart';
import 'package:dailywork/providers/my_applications_provider.dart';
import 'package:dailywork/repositories/api/api_application_repository.dart';
import 'package:dailywork/repositories/job_repository.dart';
import 'package:dailywork/screens/shared/widgets/status_badge.dart';
import 'package:dailywork/screens/shared/widgets/language_toggle_button.dart';
import 'package:dailywork/core/router/auth_gate.dart';

String _formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class WorkerJobDetailScreen extends ConsumerStatefulWidget {
  const WorkerJobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<WorkerJobDetailScreen> createState() =>
      _WorkerJobDetailScreenState();
}

class _WorkerJobDetailScreenState extends ConsumerState<WorkerJobDetailScreen> {
  bool _applying = false;

  Future<void> _apply(String jobId) async {
    setState(() => _applying = true);
    try {
      await ref.read(apiApplicationRepositoryProvider).apply(jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final apiError = ApiException.extract(e);
      // Surface the server's reason verbatim — a 409 may be a duplicate
      // ("Already applied...") or the active-job cap, which are different.
      final msg = apiError?.message ?? 'Could not apply. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _withdraw(String applicationId) async {
    final strings = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _applying = true);
    try {
      await ref.read(apiApplicationRepositoryProvider).withdraw(applicationId);
      ref.invalidate(myApplicationsProvider);
      ref.invalidate(jobDetailProvider(widget.jobId));
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(strings['application_withdrawn'] ?? 'Application withdrawn'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      final apiError = ApiException.extract(e);
      messenger.showSnackBar(SnackBar(
        content: Text(apiError?.message ?? 'Could not cancel. Please try again.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<bool> _confirmCancel() async {
    final strings = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings['cancel_application_title'] ?? 'Cancel application?'),
        content: Text(strings['cancel_application_body'] ??
            'Are you sure you want to cancel your application for this job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings['no'] ?? 'No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings['yes_cancel'] ?? 'Yes, cancel'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// The worker's own application for [jobId], or null if they haven't applied
  /// (only meaningful when authenticated as a worker).
  WorkerApplicationItem? _myApplication(String jobId) {
    final auth = ref.watch(authProvider);
    final isWorker = auth.status == AuthStatus.authenticated &&
        auth.user?.role == UserRole.worker;
    if (!isWorker) return null;
    return ref.watch(myApplicationsProvider).maybeWhen(
      data: (g) {
        for (final it in g.all) {
          if (it.job.id == jobId) return it;
        }
        return null;
      },
      orElse: () => null,
    );
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

                      // Details card
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DetailRow(
                                label: 'Category',
                                value: job.categoryName,
                              ),
                              const SizedBox(height: 8),
                              _DetailRow(
                                label: strings['wage'] ?? 'Wage',
                                value:
                                    '₹${job.wagePerDay.toStringAsFixed(0)}${strings['per_day'] ?? '/day'}',
                              ),
                              const SizedBox(height: 8),
                              _DetailRow(
                                label: strings['workers_needed'] ??
                                    'Workers Needed',
                                value: '${job.workersNeeded}',
                              ),
                              const SizedBox(height: 8),
                              _DetailRow(
                                label: strings['applicants'] ?? 'Applicants',
                                value: '${job.applicantCount}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom action: Apply, Cancel (if applied & before start date),
              // or a disabled status label.
              _buildBottomAction(job, strings),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomAction(JobModel job, Map<String, String> strings) {
    final myApp = _myApplication(job.id);
    final isActive = myApp != null &&
        (myApp.applicationStatus == 'pending' ||
            myApp.applicationStatus == 'accepted');

    // Cancellation window: allowed only before the job's start date (midnight
    // of the start day). On/after the start date, cancelling is disabled.
    final startMidnight =
        DateTime(job.startDate.year, job.startDate.month, job.startDate.day);
    final canCancelByDate = DateTime.now().isBefore(startMidnight);

    final Widget child;
    if (isActive && canCancelByDate) {
      child = ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _applying
            ? null
            : () async {
                if (await _confirmCancel()) {
                  await _withdraw(myApp.applicationId);
                }
              },
        child: _applying
            ? _spinner()
            : Text(
                strings['cancel_application'] ?? 'Cancel Application',
                style:
                    GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      );
    } else if (myApp != null) {
      // Applied, but cannot cancel: either the start date has passed or the
      // application is in a terminal state. Show the status, disabled.
      child = ElevatedButton(
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: Colors.grey[400],
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: null,
        child: Text(
          _appliedLabel(strings, myApp.applicationStatus),
          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
    } else {
      // Not applied — Apply (active only for open jobs).
      child = ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: (_applying || job.status != JobStatus.open)
            ? null
            : () async {
                if (!requireAuth(ref, context,
                    intendedPath: '/worker/jobs/${job.id}')) {
                  return;
                }
                await _apply(job.id);
              },
        child: _applying
            ? _spinner()
            : Text(
                strings['apply'] ?? 'Apply',
                style:
                    GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SizedBox(width: double.infinity, height: 56, child: child),
    );
  }

  Widget _spinner() => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );

  String _appliedLabel(Map<String, String> strings, String status) =>
      switch (status) {
        'accepted' => strings['accepted_label'] ?? 'Accepted',
        'pending' => strings['pending_label'] ?? 'Pending',
        'rejected' => strings['rejected_label'] ?? 'Rejected',
        'withdrawn' => strings['withdrawn_label'] ?? 'Withdrawn',
        _ => strings['pending_label'] ?? 'Pending',
      };
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
