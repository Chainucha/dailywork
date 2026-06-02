import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailywork/repositories/api/api_application_repository.dart';
import 'package:dailywork/screens/shared/widgets/applicant_tile.dart';

void main() {
  const applicant = ApplicantModel(
    applicationId: 'a1',
    workerId: 'w1',
    status: 'pending',
    displayName: 'Ravi Kumar',
    phoneNumber: '+19998887777',
    ratingAvg: 4.5,
  );

  testWidgets('shows name and accept/reject pills for pending applicant', (tester) async {
    var accepted = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ApplicantTile(
              applicant: applicant,
              busy: false,
              onAccept: () => accepted = true,
              onReject: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.byKey(const ValueKey('applicant-accept-a1')), findsOneWidget);
    expect(find.byKey(const ValueKey('applicant-reject-a1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('applicant-accept-a1')));
    expect(accepted, isTrue);
  });

  testWidgets('hides pills for non-pending applicant', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ApplicantTile(
              applicant: ApplicantModel(
                applicationId: 'a2', workerId: 'w2', status: 'accepted',
                displayName: 'Asha', phoneNumber: '+10000000001', ratingAvg: null,
              ),
              busy: false,
              onAccept: () {},
              onReject: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('applicant-accept-a2')), findsNothing);
    expect(find.byKey(const ValueKey('applicant-reject-a2')), findsNothing);
  });

  testWidgets('shows Rate button for accepted worker on completed job', (tester) async {
    var rated = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ApplicantTile(
              applicant: ApplicantModel(
                applicationId: 'a3', workerId: 'w3', status: 'accepted',
                displayName: 'Bhanu', phoneNumber: null, ratingAvg: null,
              ),
              busy: false,
              canReview: true,
              onAccept: () {},
              onReject: () {},
              onRate: () => rated = true,
            ),
          ),
        ),
      ),
    );
    final rateBtn = find.byKey(const ValueKey('applicant-rate-a3'));
    expect(rateBtn, findsOneWidget);
    await tester.tap(rateBtn);
    expect(rated, isTrue);
  });

  testWidgets('shows Reviewed label instead of Rate once reviewed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ApplicantTile(
              applicant: ApplicantModel(
                applicationId: 'a4', workerId: 'w4', status: 'accepted',
                displayName: 'Chitra', phoneNumber: null, ratingAvg: null,
              ),
              busy: false,
              canReview: true,
              reviewed: true,
              onAccept: () {},
              onReject: () {},
              onRate: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('applicant-rate-a4')), findsNothing);
    expect(find.text('Reviewed'), findsOneWidget);
  });
}
