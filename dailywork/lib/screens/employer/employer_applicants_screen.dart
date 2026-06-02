import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/applicants_provider.dart';
import 'package:dailywork/providers/job_provider.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/repositories/api/api_application_repository.dart';
import 'package:dailywork/repositories/api/api_review_repository.dart';
import 'package:dailywork/screens/shared/widgets/applicant_tile.dart';
import 'package:dailywork/screens/shared/widgets/review_dialog.dart';
import 'package:dailywork/screens/shared/widgets/language_toggle_button.dart';

class EmployerApplicantsScreen extends ConsumerStatefulWidget {
  const EmployerApplicantsScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<EmployerApplicantsScreen> createState() => _EmployerApplicantsScreenState();
}

class _EmployerApplicantsScreenState extends ConsumerState<EmployerApplicantsScreen> {
  String? _busyAppId;
  // Worker ids the employer has already reviewed this session (or that the
  // server reported as already reviewed via 409).
  final Set<String> _reviewedWorkers = {};

  Future<void> _act(
    String appId,
    Future<void> Function() action,
    String successKey,
  ) async {
    final strings = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyAppId = appId);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(strings[successKey] ?? 'Done')));
      // Refresh the list and any job-detail watching applicant counts.
      ref.invalidate(applicantsProvider(widget.jobId));
      ref.invalidate(jobDetailProvider(widget.jobId));
    } on Object catch (e) {
      final msg = e.toString().contains('capacity')
          ? (strings['capacity_reached_toast'] ?? 'Job has reached worker capacity')
          : (strings['action_failed_toast'] ?? 'Action failed — try again');
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busyAppId = null);
    }
  }

  Future<void> _rateWorker(ApplicantModel a) async {
    final strings = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final input = await showReviewDialog(context);
    if (input == null) return;

    setState(() => _busyAppId = a.applicationId);
    try {
      await ref.read(apiReviewRepositoryProvider).submitReview(
            revieweeId: a.workerId,
            jobId: widget.jobId,
            rating: input.rating,
            comment: input.comment,
          );
      if (!mounted) return;
      setState(() => _reviewedWorkers.add(a.workerId));
      messenger.showSnackBar(SnackBar(
        content: Text(strings['review_thanks'] ?? 'Thanks for your review!'),
      ));
    } catch (e) {
      if (!mounted) return;
      final apiError = ApiException.extract(e);
      if (apiError?.statusCode == 409) {
        setState(() => _reviewedWorkers.add(a.workerId));
      }
      messenger.showSnackBar(SnackBar(
        content: Text(apiError?.message ??
            (strings['action_failed_toast'] ?? 'Action failed — try again')),
      ));
    } finally {
      if (mounted) setState(() => _busyAppId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final repo = ref.watch(apiApplicationRepositoryProvider);
    final applicantsAsync = ref.watch(applicantsProvider(widget.jobId));
    final jobCompleted = ref.watch(jobDetailProvider(widget.jobId)).maybeWhen(
          data: (job) => job.status == JobStatus.completed,
          orElse: () => false,
        );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          strings['manage_applicants'] ?? 'Applicants',
          style: const TextStyle(color: Colors.white),
        ),
        actions: const [LanguageToggleButton()],
      ),
      body: applicantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(child: Text(strings['action_failed_toast'] ?? 'Failed to load')),
        data: (applicants) {
          if (applicants.isEmpty) {
            return Center(
              child: Text(
                strings['no_applicants'] ?? 'No applicants yet',
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(applicantsProvider(widget.jobId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: applicants.length,
              itemBuilder: (context, i) {
                final a = applicants[i];
                return ApplicantTile(
                  applicant: a,
                  busy: _busyAppId == a.applicationId,
                  canReview: jobCompleted && a.status == 'accepted',
                  reviewed: _reviewedWorkers.contains(a.workerId),
                  onRate: () => _rateWorker(a),
                  onAccept: () => _act(
                    a.applicationId,
                    () => repo.accept(a.applicationId),
                    'applicant_accepted_toast',
                  ),
                  onReject: () => _act(
                    a.applicationId,
                    () => repo.reject(a.applicationId),
                    'applicant_rejected_toast',
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
