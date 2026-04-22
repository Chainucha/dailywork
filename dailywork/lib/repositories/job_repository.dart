import '../models/category_model.dart';
import '../models/job_model.dart';
import '../models/job_filter.dart';

class EmployerJobsGrouped {
  final List<JobModel> open;
  final List<JobModel> assigned;
  final List<JobModel> inProgress;
  final List<JobModel> completed;
  final List<JobModel> cancelled;
  const EmployerJobsGrouped({
    required this.open,
    required this.assigned,
    required this.inProgress,
    required this.completed,
    required this.cancelled,
  });

  Iterable<JobModel> get all sync* {
    yield* open;
    yield* assigned;
    yield* inProgress;
    yield* completed;
    yield* cancelled;
  }
}

abstract class JobRepository {
  Future<List<JobModel>> getJobs({String? categoryId, JobFilter? filter});
  Future<JobModel> getJobById(String id);
  Future<List<CategoryModel>> getCategories();

  Future<JobModel> createJob(Map<String, dynamic> body);
  Future<JobModel> updateJob(String id, Map<String, dynamic> body);
  Future<JobModel> cancelJob(String id, {String? reason});
  Future<EmployerJobsGrouped> getMyPostedJobs();
}
