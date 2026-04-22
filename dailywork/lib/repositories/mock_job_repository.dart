import '../models/category_model.dart';
import '../models/job_model.dart';
import '../models/job_filter.dart';
import 'job_repository.dart';

class MockJobRepository implements JobRepository {
  static const List<CategoryModel> _categories = [
    CategoryModel(id: 'cat-1', name: 'Construction', iconName: 'construction'),
    CategoryModel(id: 'cat-2', name: 'Plumbing', iconName: 'plumbing'),
    CategoryModel(id: 'cat-3', name: 'Cleaning', iconName: 'cleaning_services'),
    CategoryModel(id: 'cat-4', name: 'Delivery', iconName: 'delivery_dining'),
    CategoryModel(id: 'cat-5', name: 'Electrical', iconName: 'electrical_services'),
  ];

  static final List<JobModel> _jobs = [
    // --- OPEN (urgent: startDate Apr 12 or Apr 13) ---
    JobModel(
      id: 'job-1',
      employerId: 'emp-1',
      employerName: 'Prestige Builders Group',
      categoryId: 'cat-1',
      categoryName: 'Construction',
      title: 'Mason Helper – Whitefield Project',
      description:
          'Assist senior masons with brick laying and plastering work at a residential project site in Whitefield. Safety shoes required.',
      locationLat: 12.9698,
      locationLng: 77.7499,
      addressText: 'Whitefield, Bangalore',
      wagePerDay: 600,
      workersNeeded: 4,
      workersAssigned: 2,
      status: JobStatus.open,
      startDate: DateTime(2026, 4, 12),
      endDate: DateTime(2026, 4, 20),
      startTime: '08:00:00',
      endTime: '17:00:00',
      isUrgent: true,
      createdAt: DateTime(2026, 4, 10),
      applicantCount: 3,
    ),
    JobModel(
      id: 'job-2',
      employerId: 'emp-2',
      employerName: 'CleanCo Services',
      categoryId: 'cat-3',
      categoryName: 'Cleaning',
      title: 'Office Deep Clean – Indiranagar',
      description:
          'Full deep-cleaning of a 3-floor commercial office in Indiranagar after renovation. Chemicals and equipment provided by employer.',
      locationLat: 12.9784,
      locationLng: 77.6408,
      addressText: 'Indiranagar, Bangalore',
      wagePerDay: 450,
      workersNeeded: 6,
      workersAssigned: 1,
      status: JobStatus.open,
      startDate: DateTime(2026, 4, 13),
      endDate: DateTime(2026, 4, 14),
      startTime: '06:00:00',
      endTime: '18:00:00',
      isUrgent: true,
      createdAt: DateTime(2026, 4, 10),
      applicantCount: 5,
    ),
    // --- OPEN (non-urgent) ---
    JobModel(
      id: 'job-3',
      employerId: 'emp-1',
      employerName: 'Prestige Builders Group',
      categoryId: 'cat-2',
      categoryName: 'Plumbing',
      title: 'Plumber – New Apartment Block, Sarjapur',
      description:
          'Installation of bathroom fixtures and water supply lines across 12 apartment units. Experience with CPVC pipes preferred.',
      locationLat: 12.9010,
      locationLng: 77.6965,
      addressText: 'Sarjapur, Bangalore',
      wagePerDay: 750,
      workersNeeded: 3,
      workersAssigned: 0,
      status: JobStatus.open,
      startDate: DateTime(2026, 4, 18),
      endDate: DateTime(2026, 4, 25),
      startTime: '09:00:00',
      endTime: '18:00:00',
      isUrgent: false,
      createdAt: DateTime(2026, 4, 9),
      applicantCount: 2,
    ),
    JobModel(
      id: 'job-4',
      employerId: 'emp-4',
      employerName: 'Bright Electricals',
      categoryId: 'cat-5',
      categoryName: 'Electrical',
      title: 'Electrician Helper – Koramangala Villa',
      description:
          'Assist licensed electrician with wiring, conduit fitting, and panel work at an independent villa. No solo work; always under supervision.',
      locationLat: 12.9352,
      locationLng: 77.6245,
      addressText: 'Koramangala, Bangalore',
      wagePerDay: 700,
      workersNeeded: 2,
      workersAssigned: 0,
      status: JobStatus.open,
      startDate: DateTime(2026, 4, 21),
      endDate: DateTime(2026, 4, 23),
      startTime: '10:00:00',
      endTime: '18:00:00',
      isUrgent: false,
      createdAt: DateTime(2026, 4, 9),
      applicantCount: 4,
    ),
    JobModel(
      id: 'job-5',
      employerId: 'emp-3',
      employerName: 'FastDeliver',
      categoryId: 'cat-4',
      categoryName: 'Delivery',
      title: 'Delivery Rider – Grocery Campaign, HSR Layout',
      description:
          'Handle last-mile grocery deliveries in HSR Layout and surrounding areas. Own two-wheeler required. Fuel allowance provided.',
      locationLat: 12.9116,
      locationLng: 77.6474,
      addressText: 'HSR Layout, Bangalore',
      wagePerDay: 500,
      workersNeeded: 5,
      workersAssigned: 0,
      status: JobStatus.open,
      startDate: DateTime(2026, 4, 22),
      endDate: DateTime(2026, 4, 30),
      startTime: '08:00:00',
      endTime: '20:00:00',
      isUrgent: false,
      createdAt: DateTime(2026, 4, 8),
      applicantCount: 8,
    ),
    JobModel(
      id: 'job-6',
      employerId: 'emp-2',
      employerName: 'CleanCo Services',
      categoryId: 'cat-3',
      categoryName: 'Cleaning',
      title: 'Housekeeping Staff – Tech Park, Bellandur',
      description:
          'Daily housekeeping duties including floor mopping, washroom maintenance, and waste disposal at a busy IT park campus.',
      locationLat: 12.9254,
      locationLng: 77.6762,
      addressText: 'Bellandur, Bangalore',
      wagePerDay: 400,
      workersNeeded: 8,
      workersAssigned: 0,
      status: JobStatus.open,
      startDate: DateTime(2026, 4, 28),
      endDate: DateTime(2026, 5, 10),
      startTime: '06:00:00',
      endTime: '14:00:00',
      isUrgent: false,
      createdAt: DateTime(2026, 4, 7),
      applicantCount: 12,
    ),
    // --- ASSIGNED ---
    JobModel(
      id: 'job-7',
      employerId: 'emp-1',
      employerName: 'Prestige Builders Group',
      categoryId: 'cat-1',
      categoryName: 'Construction',
      title: 'Scaffolding Erection – Hennur Road',
      description:
          'Erect and dismantle scaffolding for a G+4 residential building on Hennur Road. Prior scaffolding experience mandatory.',
      locationLat: 13.0350,
      locationLng: 77.6400,
      addressText: 'Hennur Road, Bangalore',
      wagePerDay: 800,
      workersNeeded: 5,
      workersAssigned: 5,
      status: JobStatus.assigned,
      startDate: DateTime(2026, 4, 15),
      endDate: DateTime(2026, 4, 19),
      startTime: '07:00:00',
      endTime: '17:00:00',
      isUrgent: false,
      createdAt: DateTime(2026, 4, 5),
      applicantCount: 9,
    ),
    JobModel(
      id: 'job-8',
      employerId: 'emp-4',
      employerName: 'Bright Electricals',
      categoryId: 'cat-5',
      categoryName: 'Electrical',
      title: 'Solar Panel Mounting Assistant – Yelahanka',
      description:
          'Assist in rooftop solar panel installation and cable routing at a commercial warehouse. Height work; safety harness provided.',
      locationLat: 13.1007,
      locationLng: 77.5963,
      addressText: 'Yelahanka, Bangalore',
      wagePerDay: 900,
      workersNeeded: 3,
      workersAssigned: 3,
      status: JobStatus.assigned,
      startDate: DateTime(2026, 4, 16),
      endDate: DateTime(2026, 4, 18),
      startTime: '08:00:00',
      endTime: '17:00:00',
      isUrgent: false,
      createdAt: DateTime(2026, 4, 5),
      applicantCount: 6,
    ),
    // --- IN PROGRESS ---
    JobModel(
      id: 'job-9',
      employerId: 'emp-1',
      employerName: 'Prestige Builders Group',
      categoryId: 'cat-2',
      categoryName: 'Plumbing',
      title: 'Drainage Repair – Jayanagar Site',
      description:
          'Repair and re-lay underground drainage pipes at a commercial complex. Excavation team already on-site. Plumbing tools provided.',
      locationLat: 12.9308,
      locationLng: 77.5838,
      addressText: 'Jayanagar, Bangalore',
      wagePerDay: 700,
      workersNeeded: 4,
      workersAssigned: 4,
      status: JobStatus.inProgress,
      startDate: DateTime(2026, 4, 8),
      endDate: DateTime(2026, 4, 14),
      startTime: '08:00:00',
      endTime: '17:00:00',
      isUrgent: false,
      createdAt: DateTime(2026, 4, 3),
      applicantCount: 7,
    ),
    JobModel(
      id: 'job-10',
      employerId: 'emp-3',
      employerName: 'FastDeliver',
      categoryId: 'cat-4',
      categoryName: 'Delivery',
      title: 'E-Commerce Delivery – Festive Rush, Marathahalli',
      description:
          'Handle high-volume parcel deliveries around Marathahalli and Varthur during a festive sale period. 40–50 parcels per day.',
      locationLat: 12.9591,
      locationLng: 77.7008,
      addressText: 'Marathahalli, Bangalore',
      wagePerDay: 550,
      workersNeeded: 10,
      workersAssigned: 10,
      status: JobStatus.inProgress,
      startDate: DateTime(2026, 4, 9),
      endDate: DateTime(2026, 4, 15),
      startTime: '08:00:00',
      endTime: '20:00:00',
      isUrgent: false,
      createdAt: DateTime(2026, 4, 3),
      applicantCount: 18,
    ),
    // --- COMPLETED ---
    JobModel(
      id: 'job-11',
      employerId: 'emp-2',
      employerName: 'CleanCo Services',
      categoryId: 'cat-3',
      categoryName: 'Cleaning',
      title: 'Post-Event Cleanup – Banquet Hall, Rajajinagar',
      description:
          'Full cleanup after a large wedding event at a banquet hall. Includes hall, kitchen, and outdoor areas. Work starts immediately after event ends.',
      locationLat: 12.9915,
      locationLng: 77.5530,
      addressText: 'Rajajinagar, Bangalore',
      wagePerDay: 350,
      workersNeeded: 10,
      workersAssigned: 10,
      status: JobStatus.completed,
      startDate: DateTime(2026, 3, 28),
      endDate: DateTime(2026, 3, 29),
      startTime: '20:00:00',
      endTime: '06:00:00',
      isUrgent: false,
      createdAt: DateTime(2026, 3, 25),
      applicantCount: 14,
    ),
    // --- CANCELLED ---
    JobModel(
      id: 'job-12',
      employerId: 'emp-1',
      employerName: 'Prestige Builders Group',
      categoryId: 'cat-1',
      categoryName: 'Construction',
      title: 'Site Labour – Electronic City Phase 2',
      description:
          'General site labour for ground levelling and debris clearance. Cancelled due to delayed municipal approvals.',
      locationLat: 12.8453,
      locationLng: 77.6602,
      addressText: 'Electronic City, Bangalore',
      wagePerDay: 1500,
      workersNeeded: 15,
      workersAssigned: 0,
      status: JobStatus.cancelled,
      startDate: DateTime(2026, 4, 6),
      endDate: DateTime(2026, 4, 12),
      startTime: '07:00:00',
      endTime: '17:00:00',
      isUrgent: false,
      cancellationReason: 'Delayed municipal approvals',
      createdAt: DateTime(2026, 4, 1),
      applicantCount: 0,
    ),
  ];

  @override
  Future<List<JobModel>> getJobs({String? categoryId, JobFilter? filter}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var results = List<JobModel>.from(_jobs);

    if (categoryId != null) {
      results = results.where((j) => j.categoryId == categoryId).toList();
    }

    if (filter != null) {
      if (filter.statuses.isNotEmpty) {
        results = results.where((j) => filter.statuses.contains(j.status)).toList();
      }
      results = results
          .where((j) => j.wagePerDay >= filter.minWage && j.wagePerDay <= filter.maxWage)
          .toList();
    }

    return results;
  }

  @override
  Future<JobModel> getJobById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _jobs.firstWhere(
      (j) => j.id == id,
      orElse: () => throw Exception('Job not found'),
    );
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _categories;
  }

  @override
  Future<JobModel> createJob(Map<String, dynamic> body) async {
    throw UnimplementedError('createJob not supported in mock');
  }

  @override
  Future<JobModel> updateJob(String id, Map<String, dynamic> body) async {
    throw UnimplementedError('updateJob not supported in mock');
  }

  @override
  Future<JobModel> cancelJob(String id, {String? reason}) async {
    throw UnimplementedError('cancelJob not supported in mock');
  }

  @override
  Future<EmployerJobsGrouped> getMyPostedJobs() async {
    throw UnimplementedError('getMyPostedJobs not supported in mock');
  }
}
