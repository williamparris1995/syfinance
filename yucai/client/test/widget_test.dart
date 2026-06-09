import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/main.dart';

void main() {
  testWidgets('App renders placeholder text', (WidgetTester tester) async {
    await tester.pumpWidget(const YuCaiApp());

    expect(find.text('御财 YuCai — Initializing...'), findsOneWidget);
  });
}
