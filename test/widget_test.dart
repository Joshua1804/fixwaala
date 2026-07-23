import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/app.dart';

void main() {
  testWidgets('App boots to splash', (WidgetTester tester) async {
    await tester.pumpWidget(const FixwaalaApp());
    expect(find.text('Fixwaala'), findsOneWidget);
    // The splash screen schedules a delayed navigation (and has repeating
    // animations that never "settle"), so advance a fixed duration instead
    // of pumpAndSettle to avoid leaving its timer pending at teardown.
    await tester.pump(const Duration(seconds: 3));
  });
}
