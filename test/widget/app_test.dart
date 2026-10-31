import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/app/app.dart';

void main() {
  testWidgets('home screen offers the Sentinel and locks the Warden', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RecursionApp()));

    expect(find.text('RECURSION'), findsOneWidget);
    final sentinel = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Fight Sentinel'),
    );
    final warden = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Warden — fight the Sentinel first'),
    );
    expect(sentinel.onPressed, isNotNull);
    expect(warden.onPressed, isNull);
  });
}
