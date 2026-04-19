import 'package:flutter_test/flutter_test.dart';
import 'package:dailywork/models/user_model.dart';

void main() {
  group('UserModel.fromJson displayName precedence', () {
    test('employer uses business_name over display_name', () {
      final u = UserModel.fromJson({
        'id': 'abc',
        'phone_number': '+1555',
        'user_type': 'employer',
        'display_name': 'Personal Name',
        'business_name': 'Acme Co',
      });
      expect(u.displayName, 'Acme Co');
    });

    test('worker uses display_name when present', () {
      final u = UserModel.fromJson({
        'id': 'abc',
        'phone_number': '+1555',
        'user_type': 'worker',
        'display_name': 'Alice',
      });
      expect(u.displayName, 'Alice');
    });

    test('falls back to phone_number when display_name is null', () {
      final u = UserModel.fromJson({
        'id': 'abc',
        'phone_number': '+15551112222',
        'user_type': 'worker',
        'display_name': null,
      });
      expect(u.displayName, '+15551112222');
    });
  });

  group('WorkerProfile.fromJson', () {
    test('reads jobs_completed from payload', () {
      final p = WorkerProfile.fromJson({
        'skills': ['Plumbing'],
        'availability_status': true,
        'rating_avg': 4.5,
        'total_reviews': 10,
        'jobs_completed': 7,
      });
      expect(p.jobsCompleted, 7);
      expect(p.skills, ['Plumbing']);
    });

    test('defaults jobs_completed to 0 when missing', () {
      final p = WorkerProfile.fromJson({
        'skills': [],
        'availability_status': true,
        'rating_avg': 0,
        'total_reviews': 0,
      });
      expect(p.jobsCompleted, 0);
    });
  });

  group('EmployerProfile.fromJson', () {
    test('reads jobs_posted from payload', () {
      final p = EmployerProfile.fromJson({
        'business_name': 'Acme',
        'rating_avg': 4.0,
        'total_reviews': 5,
        'jobs_posted': 12,
      });
      expect(p.jobsPosted, 12);
    });
  });
}
