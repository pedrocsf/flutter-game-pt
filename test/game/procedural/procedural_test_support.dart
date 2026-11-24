import 'dart:convert';
import 'dart:io';

import 'package:moovz_dash/game/game.dart';

ChunkLibrary loadLibraryFromDisk() {
  final json =
      jsonDecode(File(ChunkLibrary.assetPath).readAsStringSync())
          as Map<String, dynamic>;
  final sources = {
    for (final source in ChunkLibrary.tilesetSourcesOf(json))
      source: File(
        '${ChunkLibrary.tilesetDirectory}$source',
      ).readAsStringSync(),
  };
  return ChunkLibrary.fromSources(json, sources);
}

const int _gidMask = 0x1FFFFFFF;

final ChunkLibrary _referenceLibrary = loadLibraryFromDisk();

class DeclaredTileset {
  const DeclaredTileset({required this.firstGid, required this.source});

  final int firstGid;
  final String source;
}

List<DeclaredTileset> readDeclaredTilesets(String xml) {
  return RegExp(r'<tileset firstgid="(\d+)" source="([^"]*)"')
      .allMatches(xml)
      .map(
        (match) => DeclaredTileset(
          firstGid: int.parse(match.group(1)!),
          source: match.group(2)!,
        ),
      )
      .toList();
}

int Function(int) writtenToLibraryGid(String xml) {
  final libraryBySource = {
    for (final tileset in _referenceLibrary.tilesets) tileset.source: tileset,
  };
  final declared = readDeclaredTilesets(xml);
  return (gid) {
    if (gid == 0) return 0;
    final plainGid = gid & _gidMask;
    final owner = declared.lastWhere((tileset) => tileset.firstGid <= plainGid);
    final localId = plainGid - owner.firstGid;
    final library = libraryBySource[owner.source]!;
    return (gid & ~_gidMask) | (library.firstGid + localId);
  };
}

Set<int> readUsedLibraryGids(String xml) {
  final toLibrary = writtenToLibraryGid(xml);
  final gids = <int>{};
  final csvBlocks = RegExp(r'<data encoding="csv">([\s\S]*?)</data>');
  for (final block in csvBlocks.allMatches(xml)) {
    for (final value in block.group(1)!.split(RegExp(r'[,\s]+'))) {
      final gid = int.tryParse(value);
      if (gid != null && gid != 0) gids.add(toLibrary(gid) & _gidMask);
    }
  }
  for (final match in RegExp(r'<object [^>]*gid="(\d+)"').allMatches(xml)) {
    gids.add(toLibrary(int.parse(match.group(1)!)) & _gidMask);
  }
  return gids;
}

List<List<int>> readColumns(String xml, String layerName) {
  final toLibrary = writtenToLibraryGid(xml);
  final block = RegExp(
    'name="${RegExp.escape(layerName)}"'
    r'[^>]*>\s*<data encoding="csv">\s*([\s\S]*?)</data>',
  ).firstMatch(xml)!.group(1)!.trim();
  final rows = block
      .split(',\n')
      .map((row) => row.split(',').map((v) => toLibrary(int.parse(v))).toList())
      .toList();
  return List.generate(
    rows.first.length,
    (column) => List.generate(rows.length, (row) => rows[row][column]),
  );
}

class ParsedObject {
  const ParsedObject({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.properties,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final Map<String, String> properties;

  String? get type => properties['Type'];

  bool get isLow => properties['Low'] == 'true';
}

List<ParsedObject> readEnemies(String xml) {
  final group = RegExp(
    r'<objectgroup id="\d+" name="enemies">([\s\S]*?)</objectgroup>',
  ).firstMatch(xml)!.group(1)!;
  return RegExp(
    r'<object ([^>]*?)(/>|>[\s\S]*?</object>)',
  ).allMatches(group).map((match) {
    final attributes = match.group(1)!;
    double number(String name) => double.parse(
      RegExp('$name="([^"]*)"').firstMatch(attributes)!.group(1)!,
    );
    final properties = {
      for (final property in RegExp(
        r'<property name="([^"]*)"(?: type="\w+")? value="([^"]*)"/>',
      ).allMatches(match.group(2)!))
        property.group(1)!: property.group(2)!,
    };
    return ParsedObject(
      x: number('x'),
      y: number('y'),
      width: number('width'),
      height: number('height'),
      properties: properties,
    );
  }).toList();
}
