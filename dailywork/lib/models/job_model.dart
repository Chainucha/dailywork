enum JobStatus { open, assigned, inProgress, completed, cancelled }

class JobModel {
  final String id;
  final String employerId;
  final String employerName;
  final String categoryId;
  final String categoryName;
  final String title;
  final String? description;
  final double locationLat;
  final double locationLng;
  final String? addressText;
  final double wagePerDay;
  final int workersNeeded;
  final int workersAssigned;
  final JobStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final String? startTime; // "HH:MM:SS"
  final String? endTime;
  final bool isUrgent;
  final String? cancellationReason;
  final DateTime createdAt;
  final int applicantCount;

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
    this.addressText,
    required this.wagePerDay,
    required this.workersNeeded,
    required this.workersAssigned,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
    required this.isUrgent,
    this.cancellationReason,
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
      addressText: json['address_text'] as String?,
      wagePerDay: (json['wage_per_day'] as num).toDouble(),
      workersNeeded: json['workers_needed'] as int,
      workersAssigned: json['workers_assigned'] as int,
      status: parseStatus(json['status'] as String),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      isUrgent: (json['is_urgent'] as bool?) ?? false,
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      applicantCount: (json['applicant_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'category_id': categoryId,
    'title': title,
    if (description != null) 'description': description,
    'location_lat': locationLat,
    'location_lng': locationLng,
    if (addressText != null) 'address_text': addressText,
    'wage_per_day': wagePerDay,
    'workers_needed': workersNeeded,
    'start_date': startDate.toIso8601String().split('T').first,
    'end_date': endDate.toIso8601String().split('T').first,
    if (startTime != null) 'start_time': startTime,
    if (endTime != null) 'end_time': endTime,
    'is_urgent': isUrgent,
  };

  @override
  bool operator ==(Object other) => other is JobModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
