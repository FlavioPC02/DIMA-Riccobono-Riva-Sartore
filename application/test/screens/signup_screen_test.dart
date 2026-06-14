import 'package:application/core/theme/app_colors.dart';
import 'package:application/screens/signup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: SignupScreen(),
    );
  }

  group('SignupScreen UI', () {
    testWidgets('renders main titles, subtitle, and layout elements', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Sign up to start organizing your hiking trails.'), findsOneWidget);
      expect(find.byIcon(Icons.terrain), findsOneWidget);
      expect(find.byType(Form), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4)); 

      final signUpBtn = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(signUpBtn);
      expect(signUpBtn, findsOneWidget);
      
      expect(find.text('Already have an account?'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Login'), findsOneWidget);
    });

    testWidgets('toggles password visibility for both password fields', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final passwordField = find.ancestor(of: find.text('Password'), matching: find.byType(TextFormField));
      final confirmField = find.ancestor(of: find.text('Confirm password'), matching: find.byType(TextFormField));

      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, '123456');
      await tester.pump();

      final passVisibilityIconFinder = find.descendant(of: passwordField, matching: find.byType(IconButton));
      final confirmVisibilityIconFinder = find.descendant(of: confirmField, matching: find.byType(IconButton));

      expect(tester.widget<EditableText>(find.descendant(of: passwordField, matching: find.byType(EditableText))).obscureText, isTrue);
      expect(tester.widget<EditableText>(find.descendant(of: confirmField, matching: find.byType(EditableText))).obscureText, isTrue);

      await tester.ensureVisible(passVisibilityIconFinder);
      await tester.tap(passVisibilityIconFinder);
      await tester.pump();

      await tester.ensureVisible(confirmVisibilityIconFinder);
      await tester.tap(confirmVisibilityIconFinder);
      await tester.pump();

      expect(tester.widget<EditableText>(find.descendant(of: passwordField, matching: find.byType(EditableText))).obscureText, isFalse);
      expect(tester.widget<EditableText>(find.descendant(of: confirmField, matching: find.byType(EditableText))).obscureText, isFalse);
    });
  });

  group('SignupScreen Form Validation & Logic', () {
    testWidgets('enables confirm password field only when password is valid', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final passwordField = find.ancestor(of: find.text('Password'), matching: find.byType(TextFormField));
      final confirmField = find.ancestor(of: find.text('Confirm password'), matching: find.byType(TextFormField));

      expect(tester.widget<TextFormField>(confirmField).enabled, isFalse);

      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, '12345');
      await tester.pump();

      expect(tester.widget<TextFormField>(confirmField).enabled, isFalse);

      await tester.enterText(passwordField, '123456');
      await tester.pump();

      expect(tester.widget<TextFormField>(confirmField).enabled, isTrue);
    });

    testWidgets('shows validation errors for empty and invalid fields', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final signUpBtn = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(signUpBtn);
      await tester.tap(signUpBtn);
      await tester.pump();

      expect(find.text('Insert your email'), findsOneWidget);
      expect(find.text('Insert your nickname'), findsOneWidget);
      expect(find.text('Insert your password'), findsOneWidget);

      final emailField = find.ancestor(of: find.text('Email'), matching: find.byType(TextFormField));
      final passwordField = find.ancestor(of: find.text('Password'), matching: find.byType(TextFormField));
      final confirmField = find.ancestor(of: find.text('Confirm password'), matching: find.byType(TextFormField));

      await tester.ensureVisible(emailField);
      await tester.enterText(emailField, 'bademail');
      
      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, 'validPass');
      await tester.pump();
      
      await tester.ensureVisible(confirmField);
      await tester.enterText(confirmField, 'mismatchPass');

      await tester.ensureVisible(signUpBtn);
      await tester.tap(signUpBtn);
      await tester.pump();

      expect(find.text('Insert a valid email address'), findsOneWidget);
      expect(find.text('Password mismatch'), findsOneWidget);
    });
  });

  group('SignupScreen Interactions & State', () {
    testWidgets('moves focus down the form using keyboard "Next" action', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final emailField = find.ancestor(of: find.text('Email'), matching: find.byType(TextFormField));
      final passwordField = find.ancestor(of: find.text('Password'), matching: find.byType(TextFormField));
      
      await tester.ensureVisible(emailField);
      await tester.enterText(emailField, 'test@mail.com');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      final nicknameTextField = tester.widget<TextField>(find.descendant(
        of: find.ancestor(of: find.text('Nickname'), matching: find.byType(TextFormField)),
        matching: find.byType(TextField),
      ));
      expect(nicknameTextField.focusNode?.hasFocus, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      
      final passwordTextField = tester.widget<TextField>(find.descendant(
        of: passwordField,
        matching: find.byType(TextField),
      ));
      expect(passwordTextField.focusNode?.hasFocus, isTrue);

      await tester.enterText(passwordField, '123456');
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      
      final confirmTextField = tester.widget<TextField>(find.descendant(
        of: find.ancestor(of: find.text('Confirm password'), matching: find.byType(TextFormField)),
        matching: find.byType(TextField),
      ));
      expect(confirmTextField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('pops navigation when "Login" button is pressed', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
              },
              child: const Text('Open Signup'),
            ),
          );
        }),
      ));

      await tester.tap(find.text('Open Signup'));
      await tester.pumpAndSettle();

      expect(find.byType(SignupScreen), findsOneWidget);

      final loginButton = find.widgetWithText(TextButton, 'Login');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.byType(SignupScreen), findsNothing);
      expect(find.text('Open Signup'), findsOneWidget);
    });

    testWidgets('shows error banner on failed registration attempt', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final emailField = find.ancestor(of: find.text('Email'), matching: find.byType(TextFormField));
      final nicknameField = find.ancestor(of: find.text('Nickname'), matching: find.byType(TextFormField));
      final passwordField = find.ancestor(of: find.text('Password'), matching: find.byType(TextFormField));
      final confirmField = find.ancestor(of: find.text('Confirm password'), matching: find.byType(TextFormField));

      await tester.ensureVisible(emailField);
      await tester.enterText(emailField, 'test@mail.com');
      
      await tester.ensureVisible(nicknameField);
      await tester.enterText(nicknameField, 'Tester');
      
      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, 'password123');
      await tester.pump(); 
      
      await tester.ensureVisible(confirmField);
      await tester.enterText(confirmField, 'password123');

      final signUpButtonFinder = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(signUpButtonFinder);
      await tester.tap(signUpButtonFinder);
      
      await tester.pumpAndSettle();

      final buttonWidget = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(buttonWidget.onPressed, isNotNull);

      final errorBannerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == AppColors.errorBackground,
      );
      expect(errorBannerFinder, findsOneWidget);
    });
  });
}