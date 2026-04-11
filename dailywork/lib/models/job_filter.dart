import 'job_model.dart';

class JobFilter {
  final List<JobStatus> statuses; // empty = all
  final double minWage;
  final double maxWage;

  const JobFilter({
    this.statuses = const [],
    this.minWage = 200,
    this.maxWage = 2000,
  });

  JobFilter copyWith({
    List<JobStatus>? statuses,
    double? minWage,
    double? maxWage,
  }) {
    return JobFilter(
      statuses: statuses ?? this.statuses,
      minWage: minWage ?? this.minWage,
      maxWage: maxWage ?? this.maxWage,
    );
  }
}
