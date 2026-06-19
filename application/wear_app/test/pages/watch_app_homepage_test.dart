import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wear_app/features/pages/watch_app_homepage.dart';

void main() {
  Widget createWidgetUnderTest() {
    return const MaterialApp(home: WatchAppHomepage());
  }

  group('WatchAppHomepage', () {
    testWidgets('shows a CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the "Waiting for phone" message', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      // The text contains a literal newline ('\n'), so find.text must
      // match the exact string including the line break.
      expect(find.text('Waiting for\nphone'), findsOneWidget);
    });

    testWidgets('renders inside a Scaffold with the dark background color',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF0A1410));
    });

    testWidgets('does not throw on multiple pumps (no internal state '
        'churn)', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WatchAppHomepage), findsOneWidget);
    });
  });
}
