//    testWidgets('Tap on "Plan" navigates to AddActivityPage', (WidgetTester tester) async {
//      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
//      
//      await tester.pump(const Duration(seconds: 1));
//      await tester.pump(const Duration(seconds: 1));
//
//      final planButton = find.widgetWithText(ElevatedButton, 'Plan');
//      await tester.ensureVisible(planButton);
//      await tester.tap(planButton);
//      
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      expect(find.byType(AddActivityPage), findsOneWidget);
//    });
//
//    testWidgets('Tap on "Start" navigates to NavigatorScreen', (WidgetTester tester) async {
//      await tester.pumpWidget(MaterialApp(home: TrailDetailsScreen(trail: trailMap)));
//      
//      await tester.pump(const Duration(seconds: 1));
//      await tester.pump(const Duration(seconds: 1));
//
//      final planButton = find.text('Start');
//      await tester.ensureVisible(planButton);
//      await tester.tap(planButton);
//      
//      await tester.pump();
//      await tester.pump(const Duration(seconds: 1));
//
//      final exception = tester.takeException();
//      debugPrint(exception);
//
//      expect(find.byType(NavigatorScreen), findsOneWidget);
//    });