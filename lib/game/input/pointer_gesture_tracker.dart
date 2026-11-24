import 'dart:ui';

class PointerGestureTracker {
  PointerGestureTracker({required this.onJump, required this.onSlide});

  static const swipeThreshold = 30.0;

  final VoidCallback onJump;
  final VoidCallback onSlide;

  int? _activePointer;
  Offset _origin = Offset.zero;
  bool _swipeHandled = false;

  void pointerDown(int pointer, Offset position) {
    if (_activePointer != null) return;

    _activePointer = pointer;
    _origin = position;
    _swipeHandled = false;
  }

  void pointerMove(int pointer, Offset position) {
    if (pointer != _activePointer || _swipeHandled) return;

    final delta = position - _origin;
    if (delta.dy.abs() < swipeThreshold || delta.dy.abs() < delta.dx.abs()) {
      return;
    }

    _swipeHandled = true;
    if (delta.dy < 0) {
      onJump();
    } else {
      onSlide();
    }
  }

  void pointerUp(int pointer, Offset position) {
    if (pointer != _activePointer) return;

    final isTap =
        !_swipeHandled && (position - _origin).distance < swipeThreshold;
    _reset();
    if (isTap) onJump();
  }

  void pointerCancel(int pointer) {
    if (pointer != _activePointer) return;

    _reset();
  }

  void _reset() {
    _activePointer = null;
    _swipeHandled = false;
  }
}
