import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailywork/screens/shared/widgets/wizard_scaffold.dart';

void main() {
  testWidgets('renders three progress dots and child content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WizardScaffold(
            currentStep: 0,
            totalSteps: 3,
            stepLabel: 'What & where',
            child: const Text('STEP_BODY'),
            onBack: () {},
            onNext: () {},
            nextEnabled: true,
          ),
        ),
      ),
    );
    expect(find.text('STEP_BODY'), findsOneWidget);
    expect(find.byKey(const ValueKey('wizard-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('wizard-dot-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('wizard-dot-2')), findsOneWidget);
  });

  testWidgets('Next button is disabled when nextEnabled=false', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WizardScaffold(
            currentStep: 0,
            totalSteps: 3,
            stepLabel: 'What & where',
            child: const SizedBox(),
            onBack: () {},
            onNext: () {},
            nextEnabled: false,
          ),
        ),
      ),
    );
    final btn = tester.widget<ElevatedButton>(find.byKey(const ValueKey('wizard-next')));
    expect(btn.onPressed, isNull);
  });
}
