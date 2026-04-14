import 'package:flutter/material.dart';
import 'package:application/screens/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: LoginScreen(),
    );
  }

  group(
    'Login screen UI',
    () {
      testWidgets(
        'Login screen has main title and subtitle',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final mainTitleFinder = find.text('Bentornato');
          final subtitleFinder = find.text(
            'Accedi per continuare a organizzare le tue escursioni.',
          );

          expect(mainTitleFinder, findsOneWidget);
          expect(subtitleFinder, findsOneWidget);
        },
      );

      testWidgets(
        'Login screen has one form with 2 fields',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final formFinder = find.byType(Form);
          final fieldFinder = find.byType(TextFormField);

          expect(formFinder, findsOneWidget);
          expect(fieldFinder, findsExactly(2));
        },
      );

      testWidgets(
        'Form has email and password fields and an Accedi button',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final emailFinder = find.ancestor(
            of: find.text('Email'),
            matching: find.byType(TextFormField),
          );
          final passwordFinder = find.ancestor(
            of: find.text('Password'),
            matching: find.byType(TextFormField),
          );
          final buttonFinder = find.ancestor(
            of: find.text('Accedi'),
            matching: find.byType(ElevatedButton),
          );

          expect(emailFinder, findsOneWidget);
          expect(passwordFinder, findsOneWidget);
          expect(buttonFinder, findsOneWidget);
        },
      );

      testWidgets(
        'Login screen has a link to the signup screen',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final registerButtonFinder = find.ancestor(
            of: find.text('Registrati'),
            matching: find.byType(TextButton),
          );

          expect(registerButtonFinder, findsOneWidget);
        },
      );
    },
  );

  group(
    'Form validator',
    () {
      testWidgets(
        'Validate email inline errors',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final emailFormField = find.ancestor(
            of: find.text('Email'),
            matching: find.byType(TextFormField),
          );
          final submitButtonFinder = find.ancestor(
            of: find.text('Accedi'),
            matching: find.byType(ElevatedButton),
          );
          final emptyEmailErrorFinder = find.text('Inserisci la tua email');
          final invalidEmailErrorFinder = find.text(
            'Inserisci un indirizzo email valido',
          );

          // t0: no error shown
          expect(emptyEmailErrorFinder, findsNothing);
          expect(invalidEmailErrorFinder, findsNothing);

          // Trying to submit empty email
          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(const Duration(milliseconds: 100));

          expect(emptyEmailErrorFinder, findsOneWidget);

          // Trying to submit a bad formatted email
          await tester.enterText(emailFormField, 'invalidemail');

          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(const Duration(milliseconds: 100));

          expect(invalidEmailErrorFinder, findsOneWidget);

          // Submit a valid email
          await tester.enterText(emailFormField, 'valid@mail.com');

          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(const Duration(milliseconds: 100));

          expect(emptyEmailErrorFinder, findsNothing);
          expect(invalidEmailErrorFinder, findsNothing);
        },
      );

      testWidgets(
        'Validate password inline errors',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final passwordFormField = find.ancestor(
            of: find.text('Password'),
            matching: find.byType(TextFormField),
          );
          final passwordEditableField = find.descendant(
            of: passwordFormField,
            matching: find.byType(EditableText),
          );
          final submitButtonFinder = find.ancestor(
            of: find.text('Accedi'),
            matching: find.byType(ElevatedButton),
          );
          final obscureButtonFinder = find.descendant(
            of: passwordFormField,
            matching: find.byType(IconButton),
          );
          final emptyPasswordErrorFinder = find.text('Inserisci la password');
          final shortPasswordErrorFinder = find.text(
            'La password deve contenere almeno 6 caratteri',
          );

          // t0: text is obscure
          expect(
            tester.widget<EditableText>(passwordEditableField).obscureText,
            isTrue,
          );

          // Clicking on the icon toggles the obscure text
          await tester.ensureVisible(obscureButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(obscureButtonFinder);
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            tester.widget<EditableText>(passwordEditableField).obscureText,
            isFalse,
          );

          // t0: no error shown
          expect(emptyPasswordErrorFinder, findsNothing);
          expect(shortPasswordErrorFinder, findsNothing);

          // Trying to submit empty password
          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(const Duration(milliseconds: 100));

          expect(emptyPasswordErrorFinder, findsOneWidget);

          // Trying to submit a short password
          await tester.enterText(passwordFormField, 'short');

          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(const Duration(milliseconds: 100));

          expect(shortPasswordErrorFinder, findsOneWidget);

          // Submit a valid password
          await tester.enterText(passwordFormField, 'validpassword');

          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(const Duration(milliseconds: 100));

          expect(emptyPasswordErrorFinder, findsNothing);
          expect(shortPasswordErrorFinder, findsNothing);
        },
      );
    },
  );
}
