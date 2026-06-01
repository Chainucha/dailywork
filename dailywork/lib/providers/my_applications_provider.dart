import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailywork/repositories/api/api_application_repository.dart';
import 'package:dailywork/repositories/job_repository.dart';

final myApplicationsProvider =
    FutureProvider.autoDispose<WorkerApplicationsGrouped>((ref) async {
  final repo = ref.watch(apiApplicationRepositoryProvider);
  return repo.getMyApplications();
});
