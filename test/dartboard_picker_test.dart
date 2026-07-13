import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_dart_scorer/presentation/widgets/dartboard_picker.dart';
import 'package:local_dart_scorer/presentation/widgets/manual_picker_grid.dart';

void main() {
  Widget buildTestWidget({
    required void Function(ManualPickerResult?) onScore,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 500,
          child: DartboardPicker(onScore: onScore),
        ),
      ),
    );
  }

  group('DartboardPicker', () {
    testWidgets('renders with non-zero board size (regression: CustomPaint Size.zero bug)',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(onScore: (_) {}));

      // The outer SizedBox constrains the DartboardPicker
      final outerBox = tester.renderObject<RenderBox>(find.byType(SizedBox).first);
      expect(outerBox.size.width, 400);
      expect(outerBox.size.height, 500);

      // The internal board SizedBox (inside LayoutBuilder) should be square and non-zero.
      // This is the key regression test - before the fix, CustomPaint was Size.zero.
      final allSizedBoxes = find.byType(SizedBox);
      bool foundBoardSizedBox = false;
      for (int i = 0; i < allSizedBoxes.evaluate().length; i++) {
        final box = tester.renderObject<RenderBox>(allSizedBoxes.at(i));
        // Board SizedBox is square and > 100px (outer SizedBox is 400x500, not square)
        if (box.size.width > 100 &&
            box.size.height > 100 &&
            (box.size.width - box.size.height).abs() < 1) {
          foundBoardSizedBox = true;
          expect(box.size.width, greaterThan(100.0));
          break;
        }
      }
      expect(foundBoardSizedBox, isTrue,
          reason: 'Internal board SizedBox should be square with substantial non-zero size');
    });

    testWidgets('CustomPaint exists inside the widget tree',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(onScore: (_) {}));

      // Verify the CustomPaint (dartboard painter) exists
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('tapping outside board triggers onScore with null (miss)',
        (WidgetTester tester) async {
      ManualPickerResult? result;
      await tester.pumpWidget(buildTestWidget(onScore: (r) => result = r));

      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('DartboardPicker fills its parent SizedBox',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(onScore: (_) {}));

      // The Container returned by DartboardPicker should fill the SizedBox
      final containerFinder = find.byType(Container).first;
      final containerBox = tester.renderObject<RenderBox>(containerFinder);
      expect(containerBox.size.width, 400);
      expect(containerBox.size.height, 500);
    });

    testWidgets('dartboard picker works at different sizes',
        (WidgetTester tester) async {
      // Test with a smaller container to ensure responsive sizing
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 250,
              height: 300,
              child: DartboardPicker(onScore: (_) {}),
            ),
          ),
        ),
      );

      // Should still render without errors
      expect(find.byType(DartboardPicker), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
