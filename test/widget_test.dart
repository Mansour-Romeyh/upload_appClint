import 'package:flutter_test/flutter_test.dart';
import 'package:sar_app/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const SarApp(isLoggedIn: false));
    await tester.pumpAndSettle();
    expect(find.text('الرئيسية'), findsOneWidget);
  });
}
