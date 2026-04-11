import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_model.dart';
import '../models/job_filter.dart';
import 'category_provider.dart'; // for jobRepositoryProvider

// Active filter state
final jobFilterProvider = StateProvider<JobFilter>((ref) => const JobFilter());

// Job list — re-fetches when category or filter changes
final jobListProvider = FutureProvider.autoDispose<List<JobModel>>((ref) {
  final categoryId = ref.watch(selectedCategoryProvider);
  final filter = ref.watch(jobFilterProvider);
  return ref.read(jobRepositoryProvider).getJobs(categoryId: categoryId, filter: filter);
});

// Single job detail
final jobDetailProvider =
    FutureProvider.autoDispose.family<JobModel, String>((ref, id) {
  return ref.read(jobRepositoryProvider).getJobById(id);
});
