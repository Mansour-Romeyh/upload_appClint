import 'package:flutter_test/flutter_test.dart';
import 'package:sar_app/screens/customers.dart';

void main() {
  test('customer statuses are the three fixed Arabic values', () {
    expect(kCustomerStatuses, ['مهتم', 'غير مهتم', 'متابعة']);
  });
}
