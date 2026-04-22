import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/my_posted_jobs_provider.dart';
import 'package:dailywork/repositories/api/api_job_repository.dart';

class EmployerMyJobsScreen extends ConsumerWidget {
  const EmployerMyJobsScreen({super.key});

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref, JobModel job) async {
    final strings = ref.read(stringsProvider);
    String? selectedReason;
    final reasons = [
      strings['reason_other_worker'] ?? 'Found another worker',
      strings['reason_plans_changed'] ?? 'Plans changed',
      strings['reason_other'] ?? 'Other',
    ];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(strings['cancel_job_prompt'] ?? 'Why are you cancelling?',
                  style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: reasons
                    .map((r) => ChoiceChip(
                          label: Text(r),
                          selected: selectedReason == r,
                          onSelected: (_) => setState(() => selectedReason = r),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: Text(strings['cancel_job'] ?? 'Cancel job'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep job')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final repo = ref.read(apiJobRepositoryProvider);
    try {
      await repo.cancelJob(job.id, reason: selectedReason);
      ref.invalidate(myPostedJobsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings['job_cancelled'] ?? 'Job cancelled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final groupedAsync = ref.watch(myPostedJobsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(strings['tab_my_jobs'] ?? 'My Jobs',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: groupedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (grouped) {
          final all = grouped.all.toList();
          if (all.isEmpty) {
            return Center(child: Text(strings['no_posted_jobs'] ?? 'No jobs yet — tap + to post one'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myPostedJobsProvider),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _Section('Open', grouped.open, onCancel: (j) => _confirmCancel(context, ref, j)),
                _Section('Assigned', grouped.assigned, onCancel: (j) => _confirmCancel(context, ref, j)),
                _Section('In progress', grouped.inProgress),
                _Section('Completed', grouped.completed),
                _Section('Cancelled', grouped.cancelled),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.jobs, {this.onCancel});
  final String title;
  final List<JobModel> jobs;
  final void Function(JobModel)? onCancel;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
          child: Text(title,
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
        ),
        ...jobs.map((j) => Card(
              child: ListTile(
                title: Text(j.title),
                subtitle: Text('₹${j.wagePerDay.toStringAsFixed(0)} · ${j.workersAssigned}/${j.workersNeeded} hired'),
                trailing: onCancel == null
                    ? IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => context.push('/employer/jobs/${j.id}'),
                      )
                    : Wrap(spacing: 4, children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => context.push('/employer/jobs/${j.id}/edit')),
                        IconButton(icon: const Icon(Icons.cancel_outlined), onPressed: () => onCancel!(j)),
                      ]),
                onTap: () => context.push('/employer/jobs/${j.id}'),
              ),
            )),
      ],
    );
  }
}
