import 'package:equatable/equatable.dart';
import 'package:moovz_dash/game/avatar/domain/avatar_animation.dart';
import 'package:moovz_dash/game/avatar/domain/avatar_layer.dart';
import 'package:moovz_dash/game/avatar/domain/avatar_layer_style.dart';

class AvatarAppearance extends Equatable {
  const AvatarAppearance({required this.layers});

  const AvatarAppearance.standard() : layers = _standardLayers;

  static const _standardLayers = {
    AvatarLayer.body: AvatarLayerStyle(),
    AvatarLayer.pants: AvatarLayerStyle(),
    AvatarLayer.shoes: AvatarLayerStyle(),
    AvatarLayer.shirt: AvatarLayerStyle(),
    AvatarLayer.hair: AvatarLayerStyle(),
  };

  static const _assetFolder = 'anim/avatar';
  static const _standardStyle = AvatarLayerStyle();

  final Map<AvatarLayer, AvatarLayerStyle> layers;

  AvatarLayerStyle styleOf(AvatarLayer layer) {
    return layers[layer] ?? _standardStyle;
  }

  AvatarAppearance withLayer(AvatarLayer layer, AvatarLayerStyle style) {
    return copyWith(layers: {...layers, layer: style});
  }

  AvatarAppearance copyWith({Map<AvatarLayer, AvatarLayerStyle>? layers}) {
    return AvatarAppearance(layers: layers ?? this.layers);
  }

  String assetPath(AvatarLayer layer, AvatarAnimation animation) {
    final variant = styleOf(layer).variant;
    return '$_assetFolder/${layer.fileName}_${variant}_${animation.fileName}.png';
  }

  @override
  List<Object?> get props => [layers];
}
