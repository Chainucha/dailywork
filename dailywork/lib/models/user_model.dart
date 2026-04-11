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

  factory WorkerProfile.fromJson(Map<String, dynamic> json) => WorkerProfile(
    skills: (json['skills'] as List<dynamic>? ?? []).cast<String>(),
    availabilityStatus: json['availability_status'] as bool? ?? true,
    dailyWageExpectation: (json['daily_wage_expectation'] as num?)?.toDouble(),
    reliabilityPercent: 0.0,  // not tracked by backend yet
    jobsCompleted: 0,          // not tracked by backend yet
    experienceYears: 0,        // not tracked by backend yet
    ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
    totalReviews: json['total_reviews'] as int? ?? 0,
  );
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

  factory EmployerProfile.fromJson(Map<String, dynamic> json) => EmployerProfile(
    businessName: json['business_name'] as String? ?? '',
    businessType: json['business_type'] as String?,
    ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
    totalReviews: json['total_reviews'] as int? ?? 0,
  );
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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final userType = json['user_type'] as String;
    final role = userType == 'employer' ? UserRole.employer : UserRole.worker;
    return UserModel(
      id: json['id'] as String,
      phoneNumber: json['phone_number'] as String,
      role: role,
      displayName: json['phone_number'] as String,  // no display name field in backend
      workerProfile: role == UserRole.worker ? WorkerProfile.fromJson(json) : null,
      employerProfile: role == UserRole.employer ? EmployerProfile.fromJson(json) : null,
    );
  }

  @override
  bool operator ==(Object other) => other is UserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
