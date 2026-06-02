import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dailywork/screens/shared/widgets/review_dialog.dart';

void main() {
  testWidgets('Submit disabled until a star is picked, then returns rating',
      (tester) async {
    ReviewInput? result;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showReviewDialog(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Submit starts disabled (no rating yet).
    final submit = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Submit'),
    );
    expect(submit.onPressed, isNull);

    // Pick 4th star, add a comment, submit.
    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Good employer');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.rating, 4);
    expect(result!.comment, 'Good employer');
  });

  testWidgets('Dismiss returns null', (tester) async {
    ReviewInput? result;
    bool returned = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showReviewDialog(context);
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(returned, isTrue);
    expect(result, isNull);
  });
}
