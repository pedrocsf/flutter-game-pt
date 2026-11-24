import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Moovz logo rendered from the app_ui package assets.
class MoovzLogo extends StatelessWidget {
  /// Creates a [MoovzLogo].
  const MoovzLogo({this.width, this.height, super.key});

  /// Logo width in logical pixels.
  final double? width;

  /// Logo height in logical pixels.
  final double? height;

  static const String _assetPath = 'assets/logos/moovz_branco.svg';
  static const String _assetPackage = 'app_ui';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _assetPath,
      package: _assetPackage,
      width: width,
      height: height,
    );
  }
}
