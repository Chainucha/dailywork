import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/core/network/api_client.dart';
import 'package:dailywork/models/category_model.dart';
import 'package:dailywork/models/job_filter.dart';
import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/repositories/job_repository.dart';

class ApiJobRepository implements JobRepository {
  final Dio _dio;

  ApiJobRepository(this._dio);

  static String _statusName(JobStatus s) => switch (s) {
    JobStatus.inProgress => 'in_progress',
    _ => s.name,
  };

  @override
  Future<List<JobModel>> getJobs({String? categoryId, JobFilter? filter}) async {
    // Send a single status to the API when exactly one is selected; otherwise fetch all.
    final String? apiStatus = (filter != null && filter.statuses.length == 1)
        ? _statusName(filter.statuses.first)
        : null;

    final response = await _dio.get<Map<String, dynamic>>(
      '/jobs/',
      queryParameters: {
        // City-center fallback — screens that have user location should pass it via override
        'lat': 12.9716,
        'lng': 77.5946,
        'radius_km': 25,
        if (categoryId != null) 'category_id': categoryId,
        if (apiStatus != null) 'status': apiStatus,
        // wage filters are applied client-side (API does not support them)
      },
    );
    final data = response.data!;
    final jobs = (data['data'] as List<dynamic>)
        .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
        .toList();

    if (filter == null) return jobs;

    // Apply client-side filters
    return jobs.where((job) {
      // Status: if multiple statuses selected, filter client-side
      if (filter.statuses.isNotEmpty && !filter.statuses.contains(job.status)) return false;
      if (job.wagePerDay < filter.minWage) return false;
      if (job.wagePerDay > filter.maxWage) return false;
      return true;
    }).toList();
  }

  @override
  Future<JobModel> getJobById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/jobs/$id');
    return JobModel.fromJson(response.data!);
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await _dio.get<List<dynamic>>('/categories/');
    return (response.data ?? [])
        .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }
}

final apiJobRepositoryProvider = Provider<ApiJobRepository>((ref) {
  return ApiJobRepository(ref.watch(apiClientProvider));
});
