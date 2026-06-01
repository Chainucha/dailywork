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

/// Applicant row for the employer's applicant-management screen.
class ApplicantModel {
  final String applicationId;
  final String workerId;
  final String status;
  final String displayName;
  final String? phoneNumber;
  final double? ratingAvg;

  const ApplicantModel({
    required this.applicationId,
    required this.workerId,
    required this.status,
    required this.displayName,
    this.phoneNumber,
    this.ratingAvg,
  });

  factory ApplicantModel.fromJson(Map<String, dynamic> json) => ApplicantModel(
    applicationId: json['application_id'] as String,
    workerId: json['worker_id'] as String,
    status: json['status'] as String,
    displayName: (json['display_name'] as String?) ?? 'Worker',
    phoneNumber: json['phone_number'] as String?,
    ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
  );
}

class ApiApplicationRepository {
  final Dio _dio;

  ApiApplicationRepository(this._dio);

  Future<ApplicationModel> apply(String jobId) async {
    final response = await _dio.post<Map<String, dynamic>>('/jobs/$jobId/apply');
    return ApplicationModel.fromJson(response.data!);
  }

  Future<List<ApplicantModel>> listForJob(String jobId) async {
    final response = await _dio.get<Map<String, dynamic>>('/jobs/$jobId/applications');
    final data = response.data!;
    return ((data['data'] as List<dynamic>?) ?? [])
        .map((a) => ApplicantModel.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<ApplicationModel> _patch(String applicationId, Map<String, dynamic> body) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/applications/$applicationId',
      data: body,
    );
    return ApplicationModel.fromJson(response.data!);
  }

  Future<ApplicationModel> accept(String applicationId) =>
      _patch(applicationId, {'status': 'accepted'});

  Future<ApplicationModel> reject(String applicationId) =>
      _patch(applicationId, {'status': 'rejected'});

  Future<ApplicationModel> withdraw(String applicationId, {String? reason}) =>
      _patch(applicationId, {'status': 'withdrawn', 'reason': reason});
}

final apiApplicationRepositoryProvider = Provider<ApiApplicationRepository>((ref) {
  return ApiApplicationRepository(ref.watch(apiClientProvider));
});
