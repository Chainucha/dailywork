import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/repositories/api/api_job_repository.dart';
import 'package:dailywork/repositories/job_repository.dart';

final myPostedJobsProvider = FutureProvider.autoDispose<EmployerJobsGrouped>((ref) async {
  final repo = ref.watch(apiJobRepositoryProvider);
  return repo.getMyPostedJobs();
});
