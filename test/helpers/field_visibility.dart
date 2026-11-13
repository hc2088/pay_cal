import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Check painted bounds, since a clipped floating label emits no overflow error.
void expectFieldLabelVisible(WidgetTester tester, Finder field, String label) {
  final labelFinder = find.descendant(of: field, matching: find.text(label));
  expect(labelFinder, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(labelFinder);
  final labelRect = MatrixUtils.transformRect(
    paragraph.getTransformTo(null),
    Offset.zero & paragraph.size,
  );
  final fieldBox = tester.renderObject<RenderBox>(field);
  final fieldRect = MatrixUtils.transformRect(
    fieldBox.getTransformTo(null),
    Offset.zero & fieldBox.size,
  );
  void expectContains(Rect bounds) {
    expect(
      bounds.inflate(.5).contains(labelRect.topLeft),
      isTrue,
      reason: '$label starts outside its visible bounds: $labelRect / $bounds',
    );
    expect(
      bounds.inflate(.5).contains(labelRect.bottomRight),
      isTrue,
      reason: '$label ends outside its visible bounds: $labelRect / $bounds',
    );
  }

  expectContains(fieldRect);
  expect(paragraph.didExceedMaxLines, isFalse, reason: '$label is truncated');
  for (
    RenderObject? parent = paragraph.parent;
    parent != null;
    parent = parent.parent
  ) {
    if (parent is RenderClipRect && parent.clipBehavior != Clip.none) {
      final clip =
          parent.clipper?.getClip(parent.size) ?? Offset.zero & parent.size;
      expectContains(
        MatrixUtils.transformRect(parent.getTransformTo(null), clip),
      );
    }
  }
}
