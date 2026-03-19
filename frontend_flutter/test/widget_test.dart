import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpLoggedOutApp(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MyApp(isLoggedIn: false));
    await tester.pumpAndSettle();
  }

  testWidgets('app loads the auth screen for logged out users', (
    WidgetTester tester,
  ) async {
    await pumpLoggedOutApp(tester);

    expect(find.text('UNIRIDE'), findsAny);
    expect(find.text('Log In'), findsWidgets);
    expect(find.text('Get OTP'), findsOneWidget);
  });

  testWidgets('auth tabs switch between login and sign up', (
    WidgetTester tester,
  ) async {
    await pumpLoggedOutApp(tester);

    await tester.tap(find.text('Sign Up').first);
    await tester.pumpAndSettle();

    expect(find.text('Send OTP'), findsOneWidget);

    await tester.tap(find.text('Log In').first);
    await tester.pumpAndSettle();

    expect(find.text('Get OTP'), findsOneWidget);
  });

  testWidgets(
    'auth screen renders on a compact phone layout without overflow',
    (WidgetTester tester) async {
      await pumpLoggedOutApp(tester, size: const Size(320, 640));

      expect(find.text('Safe Rides'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
