import 'package:flutter_test/flutter_test.dart';
import 'package:dailywork/repositories/job_repository.dart';

void main() {
  test('WorkerApplicationsGrouped.fromJson parses buckets and metadata', () {
    final json = {
      'pending': [
        {
          'id': 'job-1',
          'employer_id': 'emp-1',
          'category_id': 'cat-1',
          'title': 'Test job',
          'location_lat': 0.0,
          'location_lng': 0.0,
          'wage_per_day': 100,
          'workers_needed': 1,
          'workers_assigned': 0,
          'status': 'open',
          'start_date': '2026-01-01',
          'end_date': '2026-01-02',
          'created_at': '2026-01-01T00:00:00Z',
          'application_id': 'app-1',
          'application_status': 'pending',
        }
      ],
      'accepted': [],
      'rejected': [],
      'withdrawn': [],
    };

    final grouped = WorkerApplicationsGrouped.fromJson(json);

    expect(grouped.pending.length, 1);
    expect(grouped.pending.first.applicationId, 'app-1');
    expect(grouped.pending.first.applicationStatus, 'pending');
    expect(grouped.pending.first.job.title, 'Test job');
    expect(grouped.all.length, 1);
  });
}
