enum UserRole { worker, employer }

class WorkerProfile {
  final List<String> skills;
  final bool availabilityStatus;
  final double? dailyWageExpectation;
  final int jobsCompleted;
  final double ratingAvg;
  final int totalReviews;

  const WorkerProfile({
    required this.skills,
    required this.availabilityStatus,
    this.dailyWageExpectation,
    required this.jobsCompleted,
    required this.ratingAvg,
    required this.totalReviews,
  });

  factory WorkerProfile.fromJson(Map<String, dynamic> json) => WorkerProfile(
        skills: (json['skills'] as List<dynamic>? ?? []).cast<String>(),
        availabilityStatus: json['availability_status'] as bool? ?? true,
        dailyWageExpectation:
            (json['daily_wage_expectation'] as num?)?.toDouble(),
        jobsCompleted: json['jobs_completed'] as int? ?? 0,
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
        totalReviews: json['total_reviews'] as int? ?? 0,
      );
}

class EmployerProfile {
  final String businessName;
  final String? businessType;
  final int jobsPosted;
  final double ratingAvg;
  final int totalReviews;

  const EmployerProfile({
    required this.businessName,
    this.businessType,
    required this.jobsPosted,
    required this.ratingAvg,
    required this.totalReviews,
  });

  factory EmployerProfile.fromJson(Map<String, dynamic> json) => EmployerProfile(
        businessName: json['business_name'] as String? ?? '',
        businessType: json['business_type'] as String?,
        jobsPosted: json['jobs_posted'] as int? ?? 0,
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
        totalReviews: json['total_reviews'] as int? ?? 0,
      );
}

class UserModel {
  final String id;
  final String phoneNumber;
  final UserRole role;
  final String displayName;
  final WorkerProfile? workerProfile;
  final EmployerProfile? employerProfile;

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

    // Precedence: employer business_name → users.display_name → phone_number.
    final businessName = json['business_name'] as String?;
    final storedDisplayName = json['display_name'] as String?;
    final phone = json['phone_number'] as String;
    final resolved = (role == UserRole.employer && businessName != null && businessName.isNotEmpty)
        ? businessName
        : (storedDisplayName != null && storedDisplayName.isNotEmpty)
            ? storedDisplayName
            : phone;

    return UserModel(
      id: json['id'] as String,
      phoneNumber: phone,
      role: role,
      displayName: resolved,
      workerProfile: role == UserRole.worker ? WorkerProfile.fromJson(json) : null,
      employerProfile: role == UserRole.employer ? EmployerProfile.fromJson(json) : null,
    );
  }

  @override
  bool operator ==(Object other) => other is UserModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
