class TunnelTiles {
  const TunnelTiles({required this.firstGid});

  static const source = 'tiles/tile_tunnel.tsx';
  static const tileCount = 16;
  static const roofStart = 0;
  static const roofMiddle = 1;
  static const roofEnd = 2;
  static const roofLamp = 3;
  static const floorTop = 4;
  static const floorFill = 5;
  static const backgroundTop = 8;
  static const backgroundMiddle = 9;
  static const backgroundLed = 10;
  static const backgroundBase = 11;
  static const entryArch = 12;
  static const exitArch = 13;
  static const lastStructureId = floorFill;
  static const firstDecorationId = backgroundTop;
  static const lastDecorationId = exitArch;

  final int firstGid;

  int gid(int localId) => firstGid + localId;

  bool isStructure(int gid) {
    final localId = gid - firstGid;
    return localId >= roofStart && localId <= lastStructureId;
  }

  bool isDecoration(int gid) {
    final localId = gid - firstGid;
    return localId >= firstDecorationId && localId <= lastDecorationId;
  }
}
