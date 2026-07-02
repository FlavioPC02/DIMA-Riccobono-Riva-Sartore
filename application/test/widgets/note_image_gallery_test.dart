import 'package:application/widgets/note_image_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail_image_network/mocktail_image_network.dart';

import '../utils/test_config.dart';

Future<void> pumpGallery(WidgetTester tester, List<String> urls) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: NoteImageGallery(imageUrls: urls)),
    ),
  );

  await tester.pump();
}

void main() {
  setUpAll(() {
    setupTest();
  });

  testWidgets('does not show navigation arrows for a single image', (
    tester,
  ) async {
    await mockNetworkImages(() async {
      await pumpGallery(tester, ['https://example.com/image1.jpg']);

      expect(find.byType(Image), findsOneWidget);

      expect(find.byIcon(Icons.chevron_left), findsNothing);

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });

  testWidgets('shows only right arrow initially', (tester) async {
    await mockNetworkImages(() async {
      await pumpGallery(tester, [
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
      ]);

      expect(find.byIcon(Icons.chevron_left), findsNothing);

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  testWidgets('scrolling to second image shows left arrow', (tester) async {
    await mockNetworkImages(() async {
      await pumpGallery(tester, [
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
      ]);

      await tester.drag(find.byType(ListView), const Offset(-500, 0));

      await tester.pump();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });
  });

  testWidgets('last image hides right arrow', (tester) async {
    await mockNetworkImages(() async {
      await pumpGallery(tester, [
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
        'https://example.com/3.jpg',
      ]);

      final rightArrow = find.byIcon(Icons.chevron_right);
      final leftArrow = find.byIcon(Icons.chevron_left);

      await tester.drag(find.byType(ListView), const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(rightArrow, findsNothing);
      expect(leftArrow, findsOneWidget);
    });
  });

  testWidgets('right arrow scrolls gallery', (tester) async {
    await mockNetworkImages(() async {
      await pumpGallery(tester, [
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
      ]);

      await tester.tap(find.byIcon(Icons.chevron_right));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });
  });

  testWidgets('left arrow scrolls back', (tester) async {
    await mockNetworkImages(() async {
      await pumpGallery(tester, [
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
      ]);

      await tester.tap(find.byIcon(Icons.chevron_right));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byIcon(Icons.chevron_left), findsNothing);

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
