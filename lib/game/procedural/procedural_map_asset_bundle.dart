import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ProceduralMapAssetBundle extends CachingAssetBundle {
  ProceduralMapAssetBundle({required this._baseBundle});

  final AssetBundle _baseBundle;
  final Map<String, String> _maps = {};

  void putMap(String key, String tmx) {
    _maps[key] = tmx;
    evict(key);
  }

  @override
  Future<ByteData> load(String key) {
    final tmx = _maps[key];
    if (tmx == null) return _baseBundle.load(key);
    final bytes = Uint8List.fromList(utf8.encode(tmx));
    return SynchronousFuture(ByteData.sublistView(bytes));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    final tmx = _maps[key];
    if (tmx != null) return SynchronousFuture(tmx);
    return super.loadString(key, cache: cache);
  }
}
