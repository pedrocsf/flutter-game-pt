import 'package:moovz_dash/game/procedural/chunk_library.dart';
import 'package:moovz_dash/game/procedural/tmx_writer.dart';

class SectionGrid {
  SectionGrid({
    required this.width,
    required this.height,
    required this._layers,
  });

  static const groundLayer = MapChunk.groundLayerName;
  static const spikesLayer = MapChunk.spikesLayerName;
  static const terrainDecorationLayer = 'decorations_terrain';
  static const decorationLayer = 'decorations';

  final int width;
  final int height;
  final Map<String, List<List<int>>> _layers;

  bool contains(int column, int row) {
    return column >= 0 && column < width && row >= 0 && row < height;
  }

  int tileAt(String layer, int column, int row) {
    if (!contains(column, row)) return 0;
    return _layers[layer]?[column][row] ?? 0;
  }

  List<int> columnOf(String layer, int column) {
    if (column < 0 || column >= width) return const [];
    return _layers[layer]?[column] ?? const [];
  }

  void setTile(String layer, int column, int row, int gid) {
    if (!contains(column, row)) return;
    final columns = _layers[layer];
    if (columns == null) return;
    columns[column][row] = gid;
  }

  TmxLayerData toLayerData(String name) {
    return TmxLayerData(name: name, columns: _layers[name]!);
  }
}
