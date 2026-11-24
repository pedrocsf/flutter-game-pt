import 'dart:ui';

import 'package:equatable/equatable.dart';

class AvatarLayerStyle extends Equatable {
  const AvatarLayerStyle({this.variant = defaultVariant, this.tint});

  static const defaultVariant = 'default';

  final String variant;
  final Color? tint;

  @override
  List<Object?> get props => [variant, tint];
}
