import 'package:moovz_dash/game/procedural/chunk_library.dart';
import 'package:moovz_dash/game/procedural/tileset_layout.dart';

class TmxObjectGroup {
  const TmxObjectGroup({required this.name, required this.objects});

  final String name;
  final List<ChunkObject> objects;
}

class TmxLayerData {
  const TmxLayerData({
    required this.name,
    required this.columns,
    this.offsetX = 0,
    this.offsetY = 0,
    this.parallaxX = 1,
    this.parallaxY = 1,
    this.opacity = 1,
  });

  final String name;
  final List<List<int>> columns;
  final double offsetX;
  final double offsetY;
  final double parallaxX;
  final double parallaxY;
  final double opacity;
}

const int _gidMask = 0x1FFFFFFF;
const List<String> _alwaysDeclaredSources = [
  'objects/tile_items_v2.tsx',
  'objects/tile_enemies_v2.tsx',
];

class _PendingGroup {
  const _PendingGroup({
    required this.name,
    required this.offsetX,
    required this.offsetY,
    required this.layers,
  });

  final String name;
  final double offsetX;
  final double offsetY;
  final List<TmxLayerData> layers;
}

class TmxWriter {
  TmxWriter({
    required this.width,
    required this.height,
    required this.tileWidth,
    required this.tileHeight,
    required this.tilesets,
  });

  final int width;
  final int height;
  final int tileWidth;
  final int tileHeight;
  final List<TilesetEntry> tilesets;

  final List<Object> _pending = [];
  final Set<int> _usedGids = {};

  late StringBuffer _body;
  late TilesetLayout _layout;
  int _nextLayerId = 1;
  int _nextObjectId = 1;

  void addGroup({
    required String name,
    required double offsetX,
    required double offsetY,
    required List<TmxLayerData> layers,
  }) {
    layers.forEach(_collectLayerGids);
    _pending.add(
      _PendingGroup(
        name: name,
        offsetX: offsetX,
        offsetY: offsetY,
        layers: layers,
      ),
    );
  }

  void addLayer(TmxLayerData layer) {
    _collectLayerGids(layer);
    _pending.add(layer);
  }

  void addObjectGroup(TmxObjectGroup group) {
    group.objects.forEach(_collectObjectGid);
    _pending.add(group);
  }

  String build() {
    _body = StringBuffer();
    _nextLayerId = 1;
    _nextObjectId = 1;
    _layout = TilesetLayout.arrange(_declaredTilesets());
    _pending.forEach(_writePending);
    final output = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" '
        'renderorder="right-down" width="$width" height="$height" '
        'tilewidth="$tileWidth" tileheight="$tileHeight" infinite="0" '
        'nextlayerid="$_nextLayerId" nextobjectid="$_nextObjectId">',
      );
    for (final placement in _layout.placements) {
      output.writeln(
        ' <tileset firstgid="${placement.firstGid}" '
        'source="${_escape(placement.source)}"/>',
      );
    }
    output
      ..write(_body)
      ..writeln('</map>');
    return output.toString();
  }

  void _writePending(Object pending) {
    switch (pending) {
      case _PendingGroup():
        _writeGroup(pending);
      case TmxLayerData():
        _writeLayer(pending, indent: ' ');
      case TmxObjectGroup():
        _writeObjectGroup(pending);
    }
  }

  void _collectLayerGids(TmxLayerData layer) {
    for (final column in layer.columns) {
      for (final gid in column) {
        if (gid != 0) _usedGids.add(gid & _gidMask);
      }
    }
  }

  void _collectObjectGid(ChunkObject object) {
    if (object.gid != 0) _usedGids.add(object.gid & _gidMask);
  }

  void _writeGroup(_PendingGroup group) {
    final attributes = StringBuffer(
      ' id="${_nextLayerId++}" name="${_escape(group.name)}"',
    );
    _writeOffsets(attributes, group.offsetX, group.offsetY);
    _body.writeln(' <group$attributes>');
    for (final layer in group.layers) {
      _writeLayer(layer, indent: '  ');
    }
    _body.writeln(' </group>');
  }

  void _writeObjectGroup(TmxObjectGroup group) {
    final id = _nextLayerId++;
    _body.writeln(' <objectgroup id="$id" name="${_escape(group.name)}">');
    for (final object in group.objects) {
      _writeObject(object);
    }
    _body.writeln(' </objectgroup>');
  }

  List<TilesetEntry> _declaredTilesets() {
    return tilesets.where(_isDeclared).toList()
      ..sort((a, b) => a.firstGid.compareTo(b.firstGid));
  }

  bool _isDeclared(TilesetEntry tileset) {
    if (_alwaysDeclaredSources.contains(tileset.source)) return true;
    if (tileset.source.startsWith(ChunkLibrary.animatedSourcePrefix)) {
      return true;
    }
    return _usedGids.any(
      (gid) => gid >= tileset.firstGid && gid <= tileset.lastGid,
    );
  }

  void _writeOffsets(StringBuffer attributes, double offsetX, double offsetY) {
    if (offsetX != 0) attributes.write(' offsetx="${_number(offsetX)}"');
    if (offsetY != 0) attributes.write(' offsety="${_number(offsetY)}"');
  }

  void _writeLayer(TmxLayerData layer, {required String indent}) {
    final attributes = StringBuffer(
      ' id="${_nextLayerId++}" name="${_escape(layer.name)}" '
      'width="$width" height="$height"',
    );
    if (layer.opacity != 1) {
      attributes.write(' opacity="${_number(layer.opacity)}"');
    }
    _writeOffsets(attributes, layer.offsetX, layer.offsetY);
    if (layer.parallaxX != 1) {
      attributes.write(' parallaxx="${_number(layer.parallaxX)}"');
    }
    if (layer.parallaxY != 1) {
      attributes.write(' parallaxy="${_number(layer.parallaxY)}"');
    }
    _body
      ..writeln('$indent<layer$attributes>')
      ..writeln('$indent <data encoding="csv">')
      ..writeln(_csv(layer.columns))
      ..writeln('$indent </data>')
      ..writeln('$indent</layer>');
  }

  String _csv(List<List<int>> columns) {
    final rows = <String>[];
    for (var row = 0; row < height; row++) {
      rows.add(columns.map((column) => _layout.remap(column[row])).join(','));
    }
    return rows.join(',\n');
  }

  void _writeObject(ChunkObject object) {
    final isPoint = object.gid == 0 && object.width == 0 && object.height == 0;
    final attributes = StringBuffer(' id="${_nextObjectId++}"');
    if (object.gid != 0) {
      attributes.write(' gid="${_layout.remap(object.gid)}"');
    }
    if (object.type == 'PlayerSpawn') {
      attributes.write(' name="Spawn"');
    }
    if (object.type.isNotEmpty) {
      attributes.write(' type="${_escape(object.type)}"');
    }
    attributes.write(' x="${_number(object.x)}" y="${_number(object.y)}"');
    if (!isPoint) {
      attributes.write(
        ' width="${_number(object.width)}" height="${_number(object.height)}"',
      );
    }
    if (object.properties.isEmpty && !isPoint) {
      _body.writeln('  <object$attributes/>');
      return;
    }
    _body.writeln('  <object$attributes>');
    _writeProperties(object.properties);
    if (isPoint) _body.writeln('   <point/>');
    _body.writeln('  </object>');
  }

  void _writeProperties(Map<String, Object> properties) {
    if (properties.isEmpty) return;
    _body.writeln('   <properties>');
    for (final key in properties.keys.toList()..sort()) {
      final value = properties[key]!;
      final typeAttribute = value is bool ? ' type="bool"' : '';
      _body.writeln(
        '    <property name="${_escape(key)}"$typeAttribute '
        'value="${_escape('$value')}"/>',
      );
    }
    _body.writeln('   </properties>');
  }

  static String _number(double value) {
    return value == value.roundToDouble() ? value.toInt().toString() : '$value';
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
