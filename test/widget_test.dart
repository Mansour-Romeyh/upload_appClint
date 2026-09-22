import 'package:flutter_test/flutter_test.dart';
import 'package:sar_app/main.dart';
import 'package:sar_app/screens/login.dart';

void main() {
  testWidgets('renders the login screen when logged out',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SarApp(isLoggedIn: false));
    await tester.pumpAndSettle();

    // Logged out → the app boots into the login screen, not the tab shell.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('SAR Employee'), findsOneWidget);
  });
}
