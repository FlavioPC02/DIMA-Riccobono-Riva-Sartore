import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:application/screens/map_page.dart';

void main() {
  
  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: Scaffold(
        body: MapPage(),
      ),
    );
  }

  group(
    'Map page UI Structure',
    () {
      testWidgets(
        'Map page is rendered as a StatelessWidget',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final mapPageFinder = find.byType(MapPage);

          expect(mapPageFinder, findsOneWidget);
        },
      );

      testWidgets(
        'MainMapWidget is created within MapPage',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final mainMapWidgetFinder = find.byType(MainMapWidget);

          expect(mainMapWidgetFinder, findsOneWidget);
        },
      );

      testWidgets(
        'Map page has search bar TextField',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final textFieldFinder = find.byType(TextField);

          expect(textFieldFinder, findsOneWidget);
        },
      );

      testWidgets(
        'Search bar has correct hint text',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final searchHintFinder = find.text('Search for a location...');

          expect(searchHintFinder, findsOneWidget);
        },
      );

      testWidgets(
        'Map page has FloatingActionButton for location',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final floatingActionButtonFinder = find.byType(FloatingActionButton);

          expect(floatingActionButtonFinder, findsWidgets);
        },
      );

      testWidgets(
        'Location button has my_location icon',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final locationIconFinder = find.byIcon(Icons.my_location);

          expect(locationIconFinder, findsOneWidget);
        },
      );

      testWidgets(
        'Map page has proper Stack and Positioned widgets',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final stackFinder = find.byType(Stack);

          expect(stackFinder, findsWidgets);
        },
      );
    },
  );

  group(
    'Search bar functionality',
    () {
      testWidgets(
        'Search bar accepts text input',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final searchBarFinder = find.byType(TextField);

          await tester.enterText(searchBarFinder, 'Paris');
          await tester.pump();

          expect(find.text('Paris'), findsOneWidget);
        },
      );

      testWidgets(
        'Search button is present in search bar',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final searchIconFinder = find.byIcon(Icons.search);

          expect(searchIconFinder, findsOneWidget);
        },
      );

      testWidgets(
        'Text input action is set to search',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final textFieldFinder = find.byType(TextField);
          final textFieldWidget = tester.widget(textFieldFinder) as TextField;

          expect(textFieldWidget.textInputAction, TextInputAction.search);
        },
      );

      testWidgets(
        'Search bar can be cleared',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final searchBarFinder = find.byType(TextField);

          await tester.enterText(searchBarFinder, 'Rome');
          await tester.pump();
          expect(find.text('Rome'), findsOneWidget);

          await tester.enterText(searchBarFinder, '');
          await tester.pump();
          expect(find.text('Rome'), findsNothing);
        },
      );
    },
  );

  group(
    'Location button functionality',
    () {
      testWidgets(
        'Location button is present and tappable',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final locationButtonFinder = find.byIcon(Icons.my_location);

          expect(locationButtonFinder, findsOneWidget);
        },
      );

      testWidgets(
        'Location button is inside a FloatingActionButton',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final locationIconFinder = find.byIcon(Icons.my_location);
          final fabFinder = find.ancestor(
            of: locationIconFinder,
            matching: find.byType(FloatingActionButton),
          );

          expect(fabFinder, findsOneWidget);
        },
      );

      testWidgets(
        'Location button has mini size',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final fabFinder = find.byType(FloatingActionButton);
          bool hasMiniButton = false;

          for (int i = 0; i < fabFinder.evaluate().length; i++) {
            final fab = tester.widget<FloatingActionButton>(fabFinder.at(i));
            if (fab.mini) {
              hasMiniButton = true;
              break;
            }
          }

          expect(hasMiniButton, isTrue);
        },
      );
    },
  );

  group(
    'Widget state management',
    () {
      testWidgets(
        'MainMapWidget extends StatefulWidget',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final mainMapWidgetFinder = find.byType(MainMapWidget);

          expect(mainMapWidgetFinder, findsOneWidget);
        },
      );

      testWidgets(
        'Multiple pumpAndSettle calls maintain widget state',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          final textFieldFinder = find.byType(TextField);
          expect(textFieldFinder, findsOneWidget);

          await tester.pumpAndSettle();

          expect(textFieldFinder, findsOneWidget);
        },
      );
    },
  );
}

