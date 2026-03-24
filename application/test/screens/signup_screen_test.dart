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
        'Validate passoword inline errors', 
        (tester) async {
          
        }
      );
    }
  );
}