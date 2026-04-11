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

  // Convenience getters
  bool get isUrgent =>
      startDate.difference(DateTime.now()).inDays <= 2 &&
      status == JobStatus.open;

  String get distancePlaceholder => '~5 km away'; // static for demo
}
