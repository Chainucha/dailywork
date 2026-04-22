import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/my_posted_jobs_provider.dart';

class EmployerHomeScreen extends ConsumerWidget {
  const EmployerHomeScreen({super.key});

  bool _startsToday(JobModel j) {
    final now = DateTime.now();
    final d = j.startDate;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final groupedAsync = ref.watch(myPostedJobsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(strings['today_digest'] ?? "Today's overview",
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: groupedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (grouped) {
          final activeToday = grouped.assigned.where(_startsToday).toList()
            ..addAll(grouped.inProgress);
          final openCount = grouped.open.length;
          final assignedCount = grouped.assigned.length;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myPostedJobsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  Expanded(child: _Stat(label: 'Open', value: openCount.toString())),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(label: 'Assigned', value: assignedCount.toString())),
                ]),
                const SizedBox(height: 16),
                Text('Active today',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                const SizedBox(height: 8),
                if (activeToday.isEmpty)
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No jobs starting today',
                        style: GoogleFonts.nunito(color: Colors.grey[600])),
                  ))
                else
                  ...activeToday.map((j) => Card(
                        child: ListTile(
                          title: Text(j.title),
                          subtitle: Text('${j.workersAssigned}/${j.workersNeeded} hired'),
                          onTap: () => context.push('/employer/jobs/${j.id}'),
                        ),
                      )),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.go('/employer/my-jobs'),
                  child: Text(strings['tab_my_jobs'] ?? 'My Jobs'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Text(value, style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.primary)),
          Text(label, style: GoogleFonts.nunito(color: Colors.grey[600])),
        ]),
      ),
    );
  }
}
