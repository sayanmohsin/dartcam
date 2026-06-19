import 'package:flutter_test/flutter_test.dart';
import 'package:local_dart_scorer/main.dart';

void main() {
  testWidgets('App launches and shows setup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DartScorerApp());

    expect(find.text('New Match'), findsOneWidget);
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('START MATCH'), findsOneWidget);
  });
}
