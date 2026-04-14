import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_model.dart';
import '../models/job_filter.dart';
import 'category_provider.dart';
import 'job_cache_provider.dart';

// Active filter state
final jobFilterProvider = StateProvider<JobFilter>((ref) => const JobFilter());

// Job list — filters the full cached job list client-side
final jobListProvider = Provider<AsyncValue<List<JobModel>>>((ref) {
  final jobsAsync = ref.watch(jobCacheProvider);
  final filter = ref.watch(jobFilterProvider);

  return jobsAsync.whenData((jobs) {
    return jobs.where((job) {
      if (filter.statuses.isNotEmpty && !filter.statuses.contains(job.status)) {
        return false;
      }
      if (job.wagePerDay < filter.minWage) {
        return false;
      }
      if (job.wagePerDay > filter.maxWage) {
        return false;
      }
      return true;
    }).toList();
  });
});

// Single job detail
final jobDetailProvider =
    FutureProvider.autoDispose.family<JobModel, String>((ref, id) {
  return ref.read(jobRepositoryProvider).getJobById(id);
});
