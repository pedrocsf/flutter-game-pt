import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/gen/assets.gen.dart';

const _mapDirectory = 'assets/map';
const _mapNames = [
  'flutter_runnergame_map_A.tmx',
  'flutter_runnergame_map_B.tmx',
  'flutter_runnergame_map_C.tmx',
];

final _tilesetSourcePattern = RegExp(r'<tileset[^>]*\ssource="([^"]+)"');
final _imageSourcePattern = RegExp(r'<image[^>]*\ssource="([^"]+)"');

String _resolve(String directory, String relativePath) =>
    File('$directory/$relativePath').uri.normalizePath().toFilePath();

void main() {
  group('map tilesets', () {
    for (final mapName in _mapNames) {
      test('$mapName references only existing tilesets and images', () {
        final map = File('$_mapDirectory/$mapName');
        expect(map.existsSync(), isTrue);

        final sources = _tilesetSourcePattern
            .allMatches(map.readAsStringSync())
            .map((match) => match.group(1)!)
            .toList();
        expect(sources, isNotEmpty);

        for (final source in sources) {
          final tileset = File(_resolve(_mapDirectory, source));
          expect(tileset.existsSync(), isTrue, reason: tileset.path);

          final images = _imageSourcePattern
              .allMatches(tileset.readAsStringSync())
              .map((match) => match.group(1)!);
          for (final image in images) {
            final imageFile = File(_resolve(tileset.parent.path, image));
            expect(imageFile.existsSync(), isTrue, reason: imageFile.path);
          }
        }
      });
    }

    test('every generated map animation asset exists on disk', () {
      for (final asset in Assets.map.anim.values) {
        final path = asset is AssetGenImage ? asset.path : asset as String;
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });
  });
}
