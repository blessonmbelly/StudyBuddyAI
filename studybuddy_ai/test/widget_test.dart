import 'package:flutter_test/flutter_test.dart';
import 'package:studybuddy_ai/main.dart';

void main() {
  testWidgets('StudyBuddy AI app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StudyBuddyApp());
    expect(find.text('StudyBuddy AI'), findsWidgets);
  });
}
