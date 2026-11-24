import 'package:flutter/material.dart';

/// {@template page_with_background}
/// A page that fills the screen, intended for landscape layouts.
/// {@endtemplate}
class PageWithBackground extends StatelessWidget {
  /// {@macro page_with_background}
  const PageWithBackground({
    required this.background,
    required this.child,
    super.key,
  });

  /// The background widget, kept for API compatibility.
  final Widget background;

  /// The child widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child);
  }
}
