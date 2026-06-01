import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/repositories/api/api_application_repository.dart';

/// Applicants for one job. `.family` keyed by jobId; autoDispose so a fresh
/// fetch runs each time the screen opens (applicant state is time-sensitive).
final applicantsProvider =
    FutureProvider.autoDispose.family<List<ApplicantModel>, String>((ref, jobId) async {
  final repo = ref.watch(apiApplicationRepositoryProvider);
  return repo.listForJob(jobId);
});
