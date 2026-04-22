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

  @override
  Future<List<JobModel>> getJobs({String? categoryId, JobFilter? filter}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/jobs/',
      queryParameters: {
        'lat': 12.9716,
        'lng': 77.5946,
        'radius_km': 25,
        'category_id': ?categoryId,
      },
    );
    final data = response.data!;
    return (data['data'] as List<dynamic>)
        .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
        .toList();
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

  @override
  Future<JobModel> createJob(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>('/jobs/', data: body);
    return JobModel.fromJson(response.data!);
  }

  @override
  Future<JobModel> updateJob(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch<Map<String, dynamic>>('/jobs/$id', data: body);
    return JobModel.fromJson(response.data!);
  }

  @override
  Future<JobModel> cancelJob(String id, {String? reason}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/jobs/$id/cancel',
      data: {'reason': reason},
    );
    return JobModel.fromJson(response.data!);
  }

  @override
  Future<EmployerJobsGrouped> getMyPostedJobs() async {
    final response = await _dio.get<Map<String, dynamic>>('/employers/me/jobs');
    final data = response.data!;
    List<JobModel> parse(String key) => ((data[key] as List<dynamic>?) ?? [])
        .map((j) => JobModel.fromJson(j as Map<String, dynamic>))
        .toList();
    return EmployerJobsGrouped(
      open: parse('open'),
      assigned: parse('assigned'),
      inProgress: parse('in_progress'),
      completed: parse('completed'),
      cancelled: parse('cancelled'),
    );
  }
}

final apiJobRepositoryProvider = Provider<ApiJobRepository>((ref) {
  return ApiJobRepository(ref.watch(apiClientProvider));
});
