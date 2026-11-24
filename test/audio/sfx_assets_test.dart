import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moovz_dash/audio/audio.dart';
import 'package:moovz_dash/audio/songs.dart';

const _assetsRoot = 'assets';

void main() {
  group('sfx assets', () {
    test('every Sfx has a mapped file', () {
      expect(sfx.keys, unorderedEquals(Sfx.values));
    });

    for (final effect in Sfx.values) {
      test('${effect.name} points to an existing file in assets/sfx', () {
        final path = sfx[effect]!;

        expect(path, startsWith('sfx/'));
        expect(File('$_assetsRoot/$path').existsSync(), isTrue);
      });
    }
  });

  group('songs assets', () {
    for (final song in songs) {
      test('${song.filename} exists in assets/music', () {
        expect(
          File('$_assetsRoot/music/${song.filename}').existsSync(),
          isTrue,
        );
      });
    }
  });
}
