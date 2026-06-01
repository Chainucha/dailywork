import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailywork/models/job_model.dart';
import 'package:dailywork/screens/shared/widgets/job_card.dart';

JobModel _job() => JobModel(
      id: 'aaaaaaaa-0001-0000-0000-000000000000',
      employerId: 'e1',
      employerName: 'BuildCo',
      categoryId: 'c1',
      categoryName: 'Construction',
      title: 'Paddy Field Harvesting',
      locationLat: 0,
      locationLng: 0,
      wagePerDay: 500,
      workersNeeded: 4,
      workersAssigned: 0,
      status: JobStatus.open,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 2),
      isUrgent: false,
      createdAt: DateTime(2026, 1, 1),
      applicantCount: 0,
    );

void main() {
  testWidgets('worker-feed card shows View Job button that routes via onTap '
      '(no inline fake-apply)', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: JobCard(
              job: _job(),
              isEmployerView: false,
              onTap: () => tapped++,
            ),
          ),
        ),
      ),
    );

    // Button reads "View Job", not "Apply" (apply lives on the detail screen).
    expect(find.text('View Job'), findsOneWidget);
    expect(find.text('Apply'), findsNothing);

    await tester.tap(find.text('View Job'));
    await tester.pump();

    // Routes to detail; does not show a false "submitted" snackbar.
    expect(tapped, 1);
    expect(find.textContaining('submitted successfully'), findsNothing);
  });
}
