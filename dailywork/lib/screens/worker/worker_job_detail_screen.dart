import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/job_provider.dart';
import 'package:dailywork/repositories/api/api_application_repository.dart';
import 'package:dailywork/screens/shared/widgets/status_badge.dart';
import 'package:dailywork/screens/shared/widgets/language_toggle_button.dart';

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
      final msg = apiError?.statusCode == 409
          ? 'You have already applied for this job'
          : apiError?.message ?? 'Could not apply. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
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

              // Apply button — only active for open jobs
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: (_applying || job.status != JobStatus.open)
                        ? null
                        : () => _apply(job.id),
                    child: _applying
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            strings['apply'] ?? 'Apply',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
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
