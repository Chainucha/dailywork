import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';
import 'package:dailywork/providers/job_provider.dart';
import 'package:dailywork/screens/shared/widgets/job_card.dart';
import 'package:dailywork/screens/shared/widgets/category_chip_bar.dart';
import 'package:dailywork/screens/shared/widgets/filter_bottom_sheet.dart';
import 'package:dailywork/screens/shared/widgets/language_toggle_button.dart';

class WorkerHomeScreen extends ConsumerWidget {
  const WorkerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final jobsAsync = ref.watch(jobListProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(
          strings['search_grow'] ?? 'Find Work & Grow',
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
              error: (e, _) => const Center(
                child: Text('Failed to load jobs'),
              ),
              data: (jobs) {
                if (jobs.isEmpty) {
                  return const Center(
                    child: Text('No jobs found'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return JobCard(
                      job: job,
                      onTap: () => context.push('/worker/jobs/${job.id}'),
                      isEmployerView: false,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
