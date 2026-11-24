enum ItemType {
  energy(energyPoints),
  medal(medalPoints),
  zoneFive(zoneFivePoints),
  extraLife(extraLifePoints);

  const ItemType(this.points);

  static const int energyPoints = 10;
  static const int medalPoints = 1000;
  static const int zoneFivePoints = 0;
  static const int extraLifePoints = 0;
  static const int extraLifeFullLivesPoints = 500;

  static const String _medalTiledType = 'Medal';
  static const String _zoneFiveTiledType = 'ZoneFive';
  static const String _extraLifeTiledType = 'ExtraLife';

  final int points;

  bool get isSpecial => this != ItemType.energy;

  static ItemType fromType(String? type) {
    return switch (type) {
      _medalTiledType => ItemType.medal,
      _zoneFiveTiledType => ItemType.zoneFive,
      _extraLifeTiledType => ItemType.extraLife,
      _ => ItemType.energy,
    };
  }
}
