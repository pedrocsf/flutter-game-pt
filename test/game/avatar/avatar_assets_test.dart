import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/game/game.dart';
import 'package:moovz_dash/gen/assets.gen.dart';

const _pngWidthOffset = 16;
const _pngHeightOffset = 20;

({int width, int height}) _pngSize(File file) {
  final header = ByteData.sublistView(file.readAsBytesSync());
  return (
    width: header.getUint32(_pngWidthOffset),
    height: header.getUint32(_pngHeightOffset),
  );
}

void main() {
  group('avatar assets', () {
    const appearance = AvatarAppearance.standard();

    for (final layer in AvatarLayer.values) {
      for (final animation in AvatarAnimation.values) {
        final path =
            '${MoovzDashGame.prefix}'
            '${appearance.assetPath(layer, animation)}';

        test('$path exists with one row of frames', () {
          final file = File(path);

          expect(file.existsSync(), isTrue);
          final size = _pngSize(file);
          expect(size.height, equals(avatarFrameSize));
          expect(size.width, equals(avatarFrameSize * animation.frameCount));
        });

        test('$path is listed in the generated assets', () {
          final generated = Assets.map.anim.avatar.values.map(
            (asset) => asset.path,
          );

          expect(generated, contains(path));
        });
      }
    }

    test('every generated avatar asset exists on disk', () {
      for (final asset in Assets.map.anim.avatar.values) {
        expect(File(asset.path).existsSync(), isTrue, reason: asset.path);
      }
    });
  });
}
