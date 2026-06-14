import 'package:application/core/theme/app_colors.dart';
import 'package:application/screens/login_screen.dart';
import 'package:application/screens/signup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: LoginScreen(),
    );
  }

  group('LoginScreen UI', () {
    testWidgets('renders main titles, subtitle, and layout elements', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Log in to continue organizing your hikes.'), findsOneWidget);

      expect(find.byIcon(Icons.terrain), findsOneWidget);

      expect(find.byType(Form), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));

      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sign Up'), findsOneWidget);
    });

    testWidgets('toggles password visibility when trailing icon is tapped', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final passwordField = find.ancestor(
        of: find.text('Password'),
        matching: find.byType(TextFormField),
      );

      final editableTextFinder = find.descendant(
        of: passwordField,
        matching: find.byType(EditableText),
      );

      final visibilityIconFinder = find.descendant(
        of: passwordField,
        matching: find.byType(IconButton),
      );

      expect(tester.widget<EditableText>(editableTextFinder).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility), findsOneWidget);

      await tester.tap(visibilityIconFinder);
      await tester.pump();

      expect(tester.widget<EditableText>(editableTextFinder).obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });
  });

  group('LoginScreen Form Validation', () {
    testWidgets('shows validation errors for empty fields', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('shows validation errors for invalid email format', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final emailField = find.ancestor(
        of: find.text('Email'),
        matching: find.byType(TextFormField),
      );

      await tester.enterText(emailField, 'invalid-email');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('shows validation errors for short password', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final emailField = find.ancestor(
        of: find.text('Email'),
        matching: find.byType(TextFormField),
      );
      final passwordField = find.ancestor(
        of: find.text('Password'),
        matching: find.byType(TextFormField),
      );

      await tester.enterText(emailField, 'test@mail.com');
      await tester.enterText(passwordField, '12345');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Please enter a valid email address'), findsNothing);
      expect(find.text('The password must contain at least 6 characters'), findsOneWidget);
    });
  });

  group('LoginScreen Interactions & State', () {
    testWidgets('navigates to SignupScreen on Sign Up button tap', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final signUpButton = find.widgetWithText(TextButton, 'Sign Up');
      
      await tester.ensureVisible(signUpButton);
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      expect(find.byType(SignupScreen), findsOneWidget);
    });

    testWidgets('shows error banner on login failure', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final emailField = find.ancestor(
        of: find.text('Email'),
        matching: find.byType(TextFormField),
      );
      final passwordField = find.ancestor(
        of: find.text('Password'),
        matching: find.byType(TextFormField),
      );
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');

      await tester.enterText(emailField, 'test@mail.com');
      await tester.enterText(passwordField, 'password123');

      await tester.tap(signInButton);
      
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsOneWidget);

      final errorBannerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == AppColors.errorBackground,
      );
      
      expect(errorBannerFinder, findsOneWidget);
      
      final errorTextFinder = find.descendant(
        of: errorBannerFinder,
        matching: find.byType(Text),
      );
      expect(errorTextFinder, findsOneWidget);
    });

    testWidgets('moves focus to password field when email is submitted (TextInputAction.next)', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final emailField = find.ancestor(
        of: find.text('Email'),
        matching: find.byType(TextFormField),
      );

      await tester.enterText(emailField, 'test@mail.com');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();

      final passwordTextField = tester.widget<TextField>(find.descendant(
        of: find.ancestor(of: find.text('Password'), matching: find.byType(TextFormField)),
        matching: find.byType(TextField),
      ));
      
      expect(passwordTextField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('triggers login when password field is submitted (TextInputAction.done)', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final emailField = find.ancestor(
        of: find.text('Email'),
        matching: find.byType(TextFormField),
      );
      final passwordField = find.ancestor(
        of: find.text('Password'),
        matching: find.byType(TextFormField),
      );

      await tester.enterText(emailField, 'test@mail.com');
      await tester.enterText(passwordField, 'password123');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      
      await tester.pumpAndSettle();

      final errorBannerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == AppColors.errorBackground,
      );
      expect(errorBannerFinder, findsOneWidget);
    });

    testWidgets('login button interacts correctly during submission attempt', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final emailField = find.ancestor(
        of: find.text('Email'),
        matching: find.byType(TextFormField),
      );
      final passwordField = find.ancestor(
        of: find.text('Password'),
        matching: find.byType(TextFormField),
      );
      final signInButtonFinder = find.widgetWithText(ElevatedButton, 'Sign In');

      await tester.enterText(emailField, 'test@mail.com');
      await tester.enterText(passwordField, 'password123');

      await tester.tap(signInButtonFinder);
      
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