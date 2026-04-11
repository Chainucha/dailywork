enum UserRole { worker, employer }

class WorkerProfile {
  final List<String> skills;
  final bool availabilityStatus;
  final double? dailyWageExpectation;
  final double reliabilityPercent;
  final int jobsCompleted;
  final int experienceYears;
  final double ratingAvg;
  final int totalReviews;

  const WorkerProfile({
    required this.skills,
    required this.availabilityStatus,
    this.dailyWageExpectation,
    required this.reliabilityPercent,
    required this.jobsCompleted,
    required this.experienceYears,
    required this.ratingAvg,
    required this.totalReviews,
  });
}

class EmployerProfile {
  final String businessName;
  final String? businessType;
  final double ratingAvg;
  final int totalReviews;

  const EmployerProfile({
    required this.businessName,
    this.businessType,
    required this.ratingAvg,
    required this.totalReviews,
  });
}

class UserModel {
  final String id;
  final String phoneNumber;
  final UserRole role;
  final String displayName;
  final WorkerProfile? workerProfile; // non-null when role == worker
  final EmployerProfile? employerProfile; // non-null when role == employer

  const UserModel({
    required this.id,
    required this.phoneNumber,
    required this.role,
    required this.displayName,
    this.workerProfile,
    this.employerProfile,
  });

  @override
  bool operator ==(Object other) => other is UserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
