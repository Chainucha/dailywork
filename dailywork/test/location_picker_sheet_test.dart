import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailywork/screens/shared/widgets/location_picker_sheet.dart';

void main() {
  testWidgets('renders the three primary actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: LocationPickerSheet(
              initialLat: 12.97, initialLng: 77.59,
              onPicked: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('loc-use-gps')), findsOneWidget);
    expect(find.byKey(const ValueKey('loc-adjust-map')), findsOneWidget);
    expect(find.byKey(const ValueKey('loc-type-address')), findsOneWidget);
  });
}
