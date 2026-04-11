enum UserRole { worker, employer }

class UserModel {
  final String id;
  final String phoneNumber;
  final UserRole role;
  final String displayName;
  // Worker-specific fields (null for employer)
  final List<String>? skills;
  final bool? availabilityStatus;
  final double? dailyWageExpectation;
  final double? reliabilityPercent; // 0-100
  final int? jobsCompleted;
  final int? experienceYears;
  final double? ratingAvg;
  // Employer-specific fields (null for worker)
  final String? businessName;
  final String? businessType;
  // Shared
  final double? ratingAvgShared; // use ratingAvg for worker, this for employer
  final int? totalReviews;

  const UserModel({
    required this.id,
    required this.phoneNumber,
    required this.role,
    required this.displayName,
    this.skills,
    this.availabilityStatus,
    this.dailyWageExpectation,
    this.reliabilityPercent,
    this.jobsCompleted,
    this.experienceYears,
    this.ratingAvg,
    this.businessName,
    this.businessType,
    this.ratingAvgShared,
    this.totalReviews,
  });
}
