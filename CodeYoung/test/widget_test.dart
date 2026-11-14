import 'package:flutter_test/flutter_test.dart';
import 'package:codeyoung/main.dart';

void main() {
  testWidgets('App renders splash screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.text('CodeYoung'), findsWidgets);
  });
}