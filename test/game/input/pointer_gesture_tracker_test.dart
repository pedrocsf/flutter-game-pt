import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';

void main() {
  group('PointerGestureTracker', () {
    late int jumps;
    late int slides;
    late PointerGestureTracker tracker;

    const origin = Offset(100, 100);
    const pastThreshold = PointerGestureTracker.swipeThreshold + 1;

    setUp(() {
      jumps = 0;
      slides = 0;
      tracker = PointerGestureTracker(
        onJump: () => jumps++,
        onSlide: () => slides++,
      );
    });

    test('a tap jumps only when the pointer is released', () {
      tracker.pointerDown(1, origin);
      expect(jumps, isZero);

      tracker.pointerUp(1, origin);
      expect(jumps, 1);
      expect(slides, isZero);
    });

    test('a small movement before release still counts as a tap', () {
      tracker
        ..pointerDown(1, origin)
        ..pointerMove(1, origin + const Offset(5, 10))
        ..pointerUp(1, origin + const Offset(5, 10));

      expect(jumps, 1);
    });

    test('swiping up jumps as soon as the threshold is crossed', () {
      tracker
        ..pointerDown(1, origin)
        ..pointerMove(1, origin - const Offset(0, pastThreshold));

      expect(jumps, 1);
      expect(slides, isZero);
    });

    test('swiping down slides as soon as the threshold is crossed', () {
      tracker
        ..pointerDown(1, origin)
        ..pointerMove(1, origin + const Offset(0, pastThreshold));

      expect(slides, 1);
      expect(jumps, isZero);
    });

    test('does not trigger before the threshold is crossed', () {
      tracker
        ..pointerDown(1, origin)
        ..pointerMove(
          1,
          origin + const Offset(0, PointerGestureTracker.swipeThreshold - 1),
        );

      expect(slides, isZero);
      expect(jumps, isZero);
    });

    test('releasing after a swipe does not trigger anything else', () {
      tracker
        ..pointerDown(1, origin)
        ..pointerMove(1, origin + const Offset(0, pastThreshold))
        ..pointerMove(1, origin + const Offset(0, pastThreshold * 2))
        ..pointerUp(1, origin + const Offset(0, pastThreshold * 2));

      expect(slides, 1);
      expect(jumps, isZero);
    });

    test('releasing after swiping back to the start does not jump', () {
      tracker
        ..pointerDown(1, origin)
        ..pointerMove(1, origin + const Offset(0, pastThreshold))
        ..pointerUp(1, origin);

      expect(slides, 1);
      expect(jumps, isZero);
    });

    test('mostly horizontal drags are ignored', () {
      tracker
        ..pointerDown(1, origin)
        ..pointerMove(1, origin + const Offset(200, pastThreshold))
        ..pointerUp(1, origin + const Offset(200, pastThreshold));

      expect(slides, isZero);
      expect(jumps, isZero);
    });

    test('ignores pointers other than the first one', () {
      tracker
        ..pointerDown(1, origin)
        ..pointerDown(2, origin)
        ..pointerMove(2, origin + const Offset(0, pastThreshold))
        ..pointerUp(2, origin);

      expect(slides, isZero);
      expect(jumps, isZero);
    });

    test('a cancelled pointer triggers nothing', () {
      tracker
        ..pointerDown(1, origin)
        ..pointerCancel(1)
        ..pointerUp(1, origin);

      expect(jumps, isZero);
    });

    test('accepts a new gesture after the previous one ended', () {
      tracker
        ..pointerDown(1, origin)
        ..pointerUp(1, origin)
        ..pointerDown(2, origin)
        ..pointerMove(2, origin + const Offset(0, pastThreshold));

      expect(jumps, 1);
      expect(slides, 1);
    });
  });
}
