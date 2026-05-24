import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bunksafe/app_state.dart';
import 'package:bunksafe/main.dart';
import 'package:bunksafe/storage.dart';

void main() {
  testWidgets('App boots and shows Today screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await tester.pumpWidget(AttendanceApp(storage: storage));
    await tester.pump();

    expect(find.text('Today'), findsWidgets);
  });

  test('AppState computes overall percent', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    final state = AppState(storage);
    // With no held classes, the overall percentage is 0%.
    expect(state.overallPercent(), 0);
  });
}
