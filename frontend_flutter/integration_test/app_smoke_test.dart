import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend_flutter/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logged out app shows auth entry points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(isLoggedIn: false));
    await tester.pumpAndSettle();

    expect(find.text('UNIRIDE'), findsAny);
    expect(find.text('Log In'), findsWidgets);
    expect(find.text('Sign Up'), findsWidgets);
  });
}
