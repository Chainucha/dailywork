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

class WorkerApplicationItem {
  final JobModel job;
  final String applicationId;
  final String applicationStatus; // pending | accepted | rejected | withdrawn
  final bool reviewed; // worker has already reviewed the employer for this job
  const WorkerApplicationItem({
    required this.job,
    required this.applicationId,
    required this.applicationStatus,
    this.reviewed = false,
  });
}

class WorkerApplicationsGrouped {
  final List<WorkerApplicationItem> pending;
  final List<WorkerApplicationItem> accepted;
  final List<WorkerApplicationItem> rejected;
  final List<WorkerApplicationItem> withdrawn;
  const WorkerApplicationsGrouped({
    required this.pending,
    required this.accepted,
    required this.rejected,
    required this.withdrawn,
  });

  List<WorkerApplicationItem> get all =>
      [...pending, ...accepted, ...rejected, ...withdrawn];

  factory WorkerApplicationsGrouped.fromJson(Map<String, dynamic> json) {
    List<WorkerApplicationItem> parse(String key) =>
        ((json[key] as List<dynamic>?) ?? []).map((e) {
      final m = e as Map<String, dynamic>;
      return WorkerApplicationItem(
        job: JobModel.fromJson(m),
        applicationId: m['application_id'] as String,
        applicationStatus: m['application_status'] as String,
        reviewed: (m['reviewed'] as bool?) ?? false,
      );
    }).toList();
    return WorkerApplicationsGrouped(
      pending: parse('pending'),
      accepted: parse('accepted'),
      rejected: parse('rejected'),
      withdrawn: parse('withdrawn'),
    );
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
