import '../models/user_model.dart';

class MockUsers {
  static final UserModel workerUser = UserModel(
    id: 'user-worker-1',
    phoneNumber: '+91 98765 43210',
    role: UserRole.worker,
    displayName: 'Basavaraj Kempanna',
    workerProfile: const WorkerProfile(
      skills: ['Plumbing', 'Masonry', 'Carpentry', 'Electrical'],
      availabilityStatus: true,
      dailyWageExpectation: 600,
      reliabilityPercent: 98,
      jobsCompleted: 120,
      experienceYears: 2,
      ratingAvg: 4.8,
      totalReviews: 45,
    ),
  );

  static final UserModel employerUser = UserModel(
    id: 'user-emp-1',
    phoneNumber: '+91 80001 00001',
    role: UserRole.employer,
    displayName: 'Prestige Builders Group',
    employerProfile: const EmployerProfile(
      businessName: 'Prestige Builders Group',
      businessType: 'Construction',
      ratingAvg: 4.6,
      totalReviews: 89,
    ),
  );

  static const List<Map<String, dynamic>> mockWorkerReviews = [
    {
      'reviewerName': 'Prestige Builders Group',
      'rating': 5,
      'comment': 'Excellent work ethic, very punctual and skilled.',
      'date': '2026-03-15',
    },
    {
      'reviewerName': 'CleanCo Services',
      'rating': 4,
      'comment': 'Good worker, completed the task efficiently.',
      'date': '2026-02-28',
    },
    {
      'reviewerName': 'Bright Electricals',
      'rating': 5,
      'comment': 'Highly recommended. Professional and reliable.',
      'date': '2026-01-20',
    },
  ];
}
