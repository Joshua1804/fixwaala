import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/app.dart';

void main() {
  testWidgets('App boots to splash', (WidgetTester tester) async {
    await tester.pumpWidget(const FixwaalaApp());
    expect(find.text('Fixwaala'), findsOneWidget);
  });
}
