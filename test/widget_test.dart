import 'package:benoit_olivier/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows operations overview with seeded records', (tester) async {
    await tester.pumpWidget(const BenoitOperationsApp(screenshotMode: true));
    await tester.pumpAndSettle();

    expect(find.text('BENOIT OLIVIER'), findsOneWidget);
    expect(find.text('Revenue analytics'), findsOneWidget);
    expect(find.text('Open tasks'), findsOneWidget);
  });

  testWidgets('creates a local visitor record', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const BenoitOperationsApp(screenshotMode: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Visitors').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('New visitor'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Mira Faye');
    await tester.enterText(find.byType(TextFormField).at(1), 'Local Audit Co');
    await tester.enterText(find.byType(TextFormField).at(2), 'Revenue review');
    await tester.enterText(find.byType(TextFormField).at(3), 'Finance');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Mira Faye'), findsOneWidget);
    expect(find.textContaining('Local Audit Co'), findsOneWidget);
  });

  testWidgets('opens visitor detail from the visitor list', (tester) async {
    await tester.pumpWidget(const BenoitOperationsApp(screenshotMode: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Visitors').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claire Marchand'));
    await tester.pumpAndSettle();

    expect(find.text('Visitor details'), findsOneWidget);
    expect(find.text('Compliance walkthrough'), findsOneWidget);
  });
}
