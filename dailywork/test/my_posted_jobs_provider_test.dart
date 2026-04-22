import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailywork/models/category_model.dart';
import 'package:dailywork/models/job_filter.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/providers/my_posted_jobs_provider.dart';
import 'package:dailywork/repositories/api/api_job_repository.dart';
import 'package:dailywork/repositories/job_repository.dart';

class _FakeRepo implements ApiJobRepository {
  @override
  Future<List<JobModel>> getJobs({String? categoryId, JobFilter? filter}) async => [];
  @override
  Future<JobModel> getJobById(String id) async => throw UnimplementedError();
  @override
  Future<List<CategoryModel>> getCategories() async => [];
  @override
  Future<JobModel> createJob(Map<String, dynamic> body) async => throw UnimplementedError();
  @override
  Future<JobModel> updateJob(String id, Map<String, dynamic> body) async => throw UnimplementedError();
  @override
  Future<JobModel> cancelJob(String id, {String? reason}) async => throw UnimplementedError();
  @override
  Future<EmployerJobsGrouped> getMyPostedJobs() async => const EmployerJobsGrouped(
        open: [], assigned: [], inProgress: [], completed: [], cancelled: [],
      );
}

void main() {
  test('myPostedJobsProvider returns grouped object from repo', () async {
    final container = ProviderContainer(overrides: [
      apiJobRepositoryProvider.overrideWithValue(_FakeRepo()),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(myPostedJobsProvider.future);
    expect(result.open, isEmpty);
    expect(result.cancelled, isEmpty);
  });
}
