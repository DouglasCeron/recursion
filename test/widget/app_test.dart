import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recursion/app/app.dart';

void main() {
  testWidgets('home screen offers to start a battle', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RecursionApp()));

    expect(find.text('RECURSION'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start battle'), findsOneWidget);
  });
}
