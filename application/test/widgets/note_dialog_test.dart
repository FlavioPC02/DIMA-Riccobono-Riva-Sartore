import 'package:application/core/models/activity_note.dart';
import 'package:application/widgets/note_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mocktail_image_network/mocktail_image_network.dart';

import '../mocks/mocks_manual.dart';
import '../utils/test_config.dart';

Future<void> pumpDialog(
  WidgetTester tester, {
  ActivityNote? note,
  ImagePicker? picker,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) =>
                    NoteDialog(existingNote: note, imagePicker: picker),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    setupTest();
  });

  testWidgets('shows empty fields for new note', (tester) async {
    await pumpDialog(tester);

    expect(find.text('New Note'), findsOneWidget);

    final textField = tester.widget<TextField>(
      find.byKey(const ValueKey('note_text_field')),
    );

    expect(textField.controller!.text, isEmpty);

    expect(find.text('Attach Photos'), findsOneWidget);
  });

  testWidgets('prefills existing note', (tester) async {
    final note = ActivityNote(
      id: '1',
      text: 'Existing note',
      imageUrls: const [],
      createdAt: DateTime.now(),
    );

    await pumpDialog(tester, note: note);

    expect(find.text('Edit Note'), findsOneWidget);
    expect(find.text('Existing note'), findsOneWidget);
  });

  testWidgets('cancel closes dialog', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('save returns entered text', (tester) async {
    dynamic result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showDialog(
                  context: context,
                  builder: (_) => const NoteDialog(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('note_text_field')),
      'My note',
    );

    await tester.tap(find.byKey(const ValueKey('save_note_button')));

    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result['text'], 'My note');
    expect(result['imageUrls'], isEmpty);
  });

  testWidgets('does not close when note is empty', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(const ValueKey('save_note_button')));

    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('picked images are shown', (tester) async {
    final picker = MockImagePicker();

    when(() => picker.pickMultiImage()).thenAnswer(
      (_) async => [XFile('/tmp/image1.jpg'), XFile('/tmp/image2.jpg')],
    );

    await pumpDialog(tester, picker: picker);

    await tester.tap(find.text('Attach Photos'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNWidgets(2));

    verify(() => picker.pickMultiImage()).called(1);
  });

  testWidgets('removes image when close icon tapped', (tester) async {
    await mockNetworkImages(() async {
      final note = ActivityNote(
        id: '1',
        text: 'note',
        imageUrls: const ['https://example.com/image.jpg'],
        createdAt: DateTime.now(),
      );

      await pumpDialog(tester, note: note);

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}
