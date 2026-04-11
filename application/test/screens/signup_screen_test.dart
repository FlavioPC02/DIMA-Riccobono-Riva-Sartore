import 'package:flutter/material.dart';

import 'package:application/screens/signup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SignupScreen(),
          ),
        ),
      );
  }
  
  group(
    'Signup screen UI',
    () {
      testWidgets(
        'Signup screen has main title and subtitle', 
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final mainTitleFinder = find.text('Welcome');
          final subtitleFinder = find.text('Sign up to start organizing your hiking trails.');

          expect(mainTitleFinder, findsOneWidget);
          expect(subtitleFinder, findsOneWidget);
        });

      testWidgets(
        'Signup screen has one form with 4 fields',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final formFinder = find.byType(Form);
          final fieldFinder = find.byType(TextFormField);
          

          expect(formFinder, findsOneWidget);
          expect(fieldFinder, findsExactly(4));
        }
      );

      testWidgets(
        'Form has 4 fields: email, nickname, password, confirm password and a confirm button',
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final emailFinder = find.ancestor(
            of: find.text('Email'), 
            matching: find.byType(TextFormField),
          );
          final nicknameFinder = find.ancestor(
            of: find.text('Email'), 
            matching: find.byType(TextFormField),
          );
          final passwordFinder = find.ancestor(
            of: find.text('Email'), 
            matching: find.byType(TextFormField),
          );
          final confirmFinder = find.ancestor(
            of: find.text('Email'), 
            matching: find.byType(TextFormField),
          );
          final buttonFinder = find.ancestor(
            of: find.text('Sign Up'),
            matching: find.byType(ElevatedButton),
          );

          expect(emailFinder, findsOneWidget);
          expect(nicknameFinder, findsOneWidget);
          expect(passwordFinder, findsOneWidget);
          expect(confirmFinder, findsOneWidget);
          expect(buttonFinder, findsOneWidget);
        } 
      ); 
    }
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
            matching: find.byType(TextFormField)
          );
          final submitButtonFinder = find.ancestor(
            of: find.text('Sign Up'),
            matching: find.byType(ElevatedButton),
          );
          final emptyEmailErrorFinder = find.text('Insert your email');
          final invalidEmailErrorFinder = find.text('Insert a valid email address');

          //t0: no error shown
          expect(emptyEmailErrorFinder, findsNothing);
          expect(invalidEmailErrorFinder, findsNothing);

          //Trying to submit empty email
          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          //Add delay before testing assertion (wait for widget to refresh)
          await tester.pump(const Duration(milliseconds: 100));
          
          expect(emptyEmailErrorFinder, findsOneWidget);

          //Trying to submit a bad formatted email
          await tester.enterText(emailFormField, 'invalidemail');
          
          //Ensure that button in on screen
          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(const Duration(milliseconds: 100));
          
          expect(invalidEmailErrorFinder, findsOneWidget);

          //Submit a valid email
          await tester.enterText(emailFormField, 'valid@mail.com');

          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(const Duration(milliseconds: 100));

          expect(emptyEmailErrorFinder, findsNothing);
          expect(invalidEmailErrorFinder, findsNothing);
        }
      );

      testWidgets(
        'Validate nickname inline errors', 
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final nicknameFormField = find.ancestor(
            of: find.text('Nickname'), 
            matching: find.byType(TextFormField)
          );
          final submitButtonFinder = find.ancestor(
            of: find.text('Sign Up'),
            matching: find.byType(ElevatedButton),
          );
          final emptyNicknameErrorFinder = find.text('Insert your nickname');

          //t0: no error shown
          expect(emptyNicknameErrorFinder, findsNothing);

          //Trying to submit empty nickname
          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(Duration(milliseconds: 100));
          expect(emptyNicknameErrorFinder, findsOneWidget);

          //Submit valid nickname
          await tester.enterText(nicknameFormField, 'validNickname');

          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(Duration(milliseconds: 100));
          expect(emptyNicknameErrorFinder, findsNothing);
        }
      );

      testWidgets(
        'Validate password inline errors', 
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final passwordFormField = find.ancestor(
            of: find.text('Password'), 
            matching: find.byType(TextFormField)
          );
          final passwordEditableField = find.descendant(
            of: passwordFormField, 
            matching: find.byType(EditableText)
          );
          final submitButtonFinder = find.ancestor(
            of: find.text('Sign Up'),
            matching: find.byType(ElevatedButton),
          );
          final obscureButtonFinder = find.descendant(
            of: passwordFormField, 
            matching: find.byType(IconButton),
          );
          final emptyPasswordErrorFinder = find.text('Insert your password');
          final shortPasswordErrorFinder = find.text('Password must be at least six-characters long');

          //Testing obscure text
          //t0: text is obscure 
          EditableText passwordInput = tester.widget<EditableText>(passwordEditableField);
          expect(passwordInput.obscureText, isTrue);

          //clicking on the icon changes the obscure text
          await tester.ensureVisible(obscureButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(obscureButtonFinder);
          await tester.pumpAndSettle();

          passwordInput = tester.widget<EditableText>(passwordEditableField);
          expect(passwordInput.obscureText, isFalse);

          //t0: no error shown
          expect(emptyPasswordErrorFinder, findsNothing);
          expect(shortPasswordErrorFinder, findsNothing);

          //Trying to submit empty password
          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(Duration(milliseconds: 100));
          expect(emptyPasswordErrorFinder, findsOneWidget);

          //Trying to submit short password
          await tester.enterText(passwordFormField, 'short');

          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(Duration(milliseconds: 100));
          expect(shortPasswordErrorFinder, findsOneWidget);

          //Submit valid password
          await tester.enterText(passwordFormField, 'valid password');

          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pump(Duration(milliseconds: 100));
          expect(emptyPasswordErrorFinder, findsNothing);
          expect(shortPasswordErrorFinder, findsNothing);
        }
      );

      testWidgets(
        'Validate confirm password inline error', 
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final passwordFormField = find.ancestor(
            of: find.text('Password'), 
            matching: find.byType(TextFormField),
          );
          final confirmPasswordFormField = find.ancestor(
            of: find.text('Confirm password'), 
            matching: find.byType(TextFormField)
          );
          final confirmPasswordEditableField = find.descendant(
            of: confirmPasswordFormField, 
            matching: find.byType(EditableText)
          );
          final submitButtonFinder = find.ancestor(
            of: find.text('Sign Up'),
            matching: find.byType(ElevatedButton),
          );
          final obscureButtonFinder = find.descendant(
            of: confirmPasswordFormField,
            matching: find.byType(IconButton),
          );
          final emptyPasswordErrorFinder = find.text('Confirm your password');
          final mismatchPasswordErrorFinder = find.text('Password mismatch');

          //t0: confirm password form field disabled
          TextFormField confirmPasswordInputWidget = tester.widget<TextFormField>(confirmPasswordFormField);
          expect(confirmPasswordInputWidget.enabled, isFalse);

          //Write valid password -> confirm password enabled
          await tester.enterText(passwordFormField, 'password');
          await tester.pumpAndSettle();

          confirmPasswordInputWidget = tester.widget<TextFormField>(confirmPasswordFormField);
          expect(confirmPasswordInputWidget.enabled, isTrue);

          //Testing obscure text
          //t0: text is obscure 
          EditableText confirmPasswordInput = tester.widget<EditableText>(confirmPasswordEditableField);
          expect(confirmPasswordInput.obscureText, isTrue);

          //clicking on the icon changes the obscure text
          await tester.ensureVisible(obscureButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(obscureButtonFinder);
          await tester.pumpAndSettle();

          confirmPasswordInput = tester.widget<EditableText>(confirmPasswordEditableField);
          expect(confirmPasswordInput.obscureText, isFalse);

          //t0: no error shown
          expect(emptyPasswordErrorFinder, findsNothing);
          expect(mismatchPasswordErrorFinder, findsNothing);

          //Trying to submit no confirm password
          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pumpAndSettle();

          expect(emptyPasswordErrorFinder, findsOneWidget);

          //Trying to submit password mismatch
          await tester.enterText(confirmPasswordFormField, 'wrong password');

          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pumpAndSettle();

          expect(mismatchPasswordErrorFinder, findsOneWidget);

          //Trying to submit correct password
          await tester.enterText(confirmPasswordFormField, 'password');

          await tester.ensureVisible(submitButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(submitButtonFinder);
          await tester.pumpAndSettle();

          expect(emptyPasswordErrorFinder, findsNothing);
          expect(mismatchPasswordErrorFinder, findsNothing);
        }
      );
    }
  );

  /* TODO: decommenta quando ci sarà pagina login finita
  group(
    'Integration tests', 
    () {
      testWidgets(
        'Change to login page', 
        (tester) async {
          await tester.pumpWidget(createWidgetUnderTest());

          final loginButtonFinder = find.ancestor(
            of: find.text('Login'), 
            matching: find.byType(TextButton),
          );
          final loginPageFinder = find.byKey(Key('login'));
          final signupPageFinder = find.byKey(Key('signup'));

          //t0: signup page
          expect(loginPageFinder, findsNothing);
          expect(signupPageFinder, findsOneWidget);

          //Clicking on login button moves to login page
          await tester.ensureVisible(loginButtonFinder);
          await tester.pumpAndSettle();
          await tester.tap(loginButtonFinder);
          await tester.pumpAndSettle();

          expect(loginPageFinder, findsOneWidget);
          expect(signupPageFinder, findsNothing);
        }
      );
    }
  );
  */
}