import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/job_provider.dart';
import 'package:dailywork/screens/shared/widgets/job_card.dart';
import 'package:dailywork/screens/shared/widgets/category_chip_bar.dart';
import 'package:dailywork/screens/shared/widgets/filter_bottom_sheet.dart';
import 'package:dailywork/screens/shared/widgets/language_toggle_button.dart';

class EmployerHomeScreen extends ConsumerWidget {
  const EmployerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final jobsAsync = ref.watch(jobListProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(
          strings['my_jobs'] ?? 'My Posted Jobs',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            tooltip: strings['filter'] ?? 'Filter',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const FilterBottomSheet(),
              );
            },
          ),
          const LanguageToggleButton(),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const CategoryChipBar(),
          const SizedBox(height: 8),
          Expanded(
            child: jobsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load jobs',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(jobListProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              data: (jobs) => RefreshIndicator(
                color: AppTheme.accent,
                onRefresh: () async {
                  ref.invalidate(jobListProvider);
                },
                child: jobs.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.work_off_outlined, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No jobs posted yet',
                                  style: GoogleFonts.nunito(
                                    fontSize: 18,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the + button to post a job',
                                  style: GoogleFonts.nunito(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: jobs.length,
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        return JobCard(
                          job: job,
                          onTap: () => context.push('/employer/jobs/${job.id}'),
                          isEmployerView: true,
                        );
                      },
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
