enum JobStatus { open, assigned, inProgress, completed, cancelled }

class JobModel {
  final String id;
  final String employerId;
  final String employerName; // denormalized for display
  final String categoryId;
  final String categoryName; // denormalized for display
  final String title;
  final String? description;
  final double locationLat;
  final double locationLng;
  final double wagePerDay;
  final int workersNeeded;
  final int workersAssigned;
  final JobStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final int applicantCount; // for employer view

  const JobModel({
    required this.id,
    required this.employerId,
    required this.employerName,
    required this.categoryId,
    required this.categoryName,
    required this.title,
    this.description,
    required this.locationLat,
    required this.locationLng,
    required this.wagePerDay,
    required this.workersNeeded,
    required this.workersAssigned,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.applicantCount,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    JobStatus parseStatus(String s) => switch (s) {
      'open'        => JobStatus.open,
      'assigned'    => JobStatus.assigned,
      'in_progress' => JobStatus.inProgress,
      'completed'   => JobStatus.completed,
      'cancelled'   => JobStatus.cancelled,
      _             => JobStatus.open,
    };

    return JobModel(
      id: json['id'] as String,
      employerId: json['employer_id'] as String,
      employerName: (json['employer_name'] as String?) ?? '',
      categoryId: json['category_id'] as String,
      categoryName: (json['category_name'] as String?) ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      locationLat: (json['location_lat'] as num).toDouble(),
      locationLng: (json['location_lng'] as num).toDouble(),
      wagePerDay: (json['wage_per_day'] as num).toDouble(),
      workersNeeded: json['workers_needed'] as int,
      workersAssigned: json['workers_assigned'] as int,
      status: parseStatus(json['status'] as String),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      applicantCount: (json['applicant_count'] as num?)?.toInt() ?? 0,
    );
  }

  // Convenience getters
  bool get isUrgent =>
      startDate.difference(DateTime.now()).inDays <= 2 &&
      status == JobStatus.open;

  @override
  bool operator ==(Object other) => other is JobModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
