import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/core/network/api_client.dart';

/// Minimal Application DTO — only the fields the UI currently needs.
class ApplicationModel {
  final String id;
  final String jobId;
  final String workerId;
  final String status;

  const ApplicationModel({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.status,
  });

  factory ApplicationModel.fromJson(Map<String, dynamic> json) => ApplicationModel(
    id: json['id'] as String,
    jobId: json['job_id'] as String,
    workerId: json['worker_id'] as String,
    status: json['status'] as String,
  );
}

class ApiApplicationRepository {
  final Dio _dio;

  ApiApplicationRepository(this._dio);

  Future<ApplicationModel> apply(String jobId) async {
    final response = await _dio.post<Map<String, dynamic>>('/jobs/$jobId/apply');
    return ApplicationModel.fromJson(response.data!);
  }

  Future<List<ApplicationModel>> listForJob(String jobId) async {
    final response = await _dio.get<Map<String, dynamic>>('/jobs/$jobId/applications');
    final data = response.data!;
    return (data['data'] as List<dynamic>)
        .map((a) => ApplicationModel.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<ApplicationModel> updateStatus(String applicationId, String status) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/applications/$applicationId',
      data: {'status': status},
    );
    return ApplicationModel.fromJson(response.data!);
  }
}

final apiApplicationRepositoryProvider = Provider<ApiApplicationRepository>((ref) {
  return ApiApplicationRepository(ref.watch(apiClientProvider));
});
