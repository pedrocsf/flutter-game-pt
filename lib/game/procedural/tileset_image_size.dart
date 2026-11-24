class TilesetImageSize {
  const TilesetImageSize({required this.width, required this.height});

  const TilesetImageSize.none() : width = 0, height = 0;

  factory TilesetImageSize.parse(String tileset) {
    var width = 0;
    var height = 0;
    for (final tag in _imageTag.allMatches(tileset)) {
      final attributes = tag.group(1)!;
      width = _max(width, _readAttribute(_widthAttribute, attributes));
      height = _max(height, _readAttribute(_heightAttribute, attributes));
    }
    return TilesetImageSize(width: width, height: height);
  }

  static final _imageTag = RegExp(r'<image\s([^>]*?)/?>');
  static final _widthAttribute = RegExp(r'\bwidth="(\d+)"');
  static final _heightAttribute = RegExp(r'\bheight="(\d+)"');

  final int width;
  final int height;

  bool get hasImage => width > 0 && height > 0;

  static int _readAttribute(RegExp pattern, String attributes) {
    final value = pattern.firstMatch(attributes)?.group(1);
    return value == null ? 0 : int.parse(value);
  }

  static int _max(int a, int b) => a > b ? a : b;
}
