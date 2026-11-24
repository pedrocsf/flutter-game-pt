part of 'game_bloc.dart';

class GameState extends Equatable {
  const GameState({
    required this.score,
    required this.currentLevel,
    required this.currentSection,
    this.lives = initialLives,
    this.lastSpecialItem,
    this.specialItemSequence = 0,
  });

  const GameState.initial()
    : score = 0,
      currentLevel = 1,
      currentSection = 0,
      lives = initialLives,
      lastSpecialItem = null,
      specialItemSequence = 0;

  static const int initialLives = 3;
  static const int maxLives = 5;

  final int score;
  final int currentLevel;
  final int currentSection;
  final int lives;
  final ItemType? lastSpecialItem;
  final int specialItemSequence;

  GameState copyWith({
    int? score,
    int? currentLevel,
    int? currentSection,
    int? lives,
    ItemType? lastSpecialItem,
    int? specialItemSequence,
  }) {
    return GameState(
      score: score ?? this.score,
      currentLevel: currentLevel ?? this.currentLevel,
      currentSection: currentSection ?? this.currentSection,
      lives: lives ?? this.lives,
      lastSpecialItem: lastSpecialItem ?? this.lastSpecialItem,
      specialItemSequence: specialItemSequence ?? this.specialItemSequence,
    );
  }

  @override
  List<Object?> get props => [
    score,
    currentLevel,
    currentSection,
    lives,
    lastSpecialItem,
    specialItemSequence,
  ];
}
