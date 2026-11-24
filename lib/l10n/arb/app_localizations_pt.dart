// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get gameIntroPageHeadline =>
      'Faça check-in no Moovz Dash, desvie dos obstáculos, colete medalhas e veja até onde seu treino vai!';

  @override
  String get gameIntroPagePlayButtonText => 'Jogar';

  @override
  String get gameInstructionsPageAutoRunTitle => 'O Dash corre sozinho';

  @override
  String get gameInstructionsPageAutoRunDescription =>
      'Bem-vindo ao Moovz Dash. Neste treino, o Dash corre automaticamente.';

  @override
  String get gameInstructionsPageTapToJumpTitle => 'Toque para pular';

  @override
  String get gameInstructionsPageTapToJumpDescription =>
      'Toque na tela para o Dash pular.';

  @override
  String get gameInstructionsPageTapToJumpDescriptionDesktop =>
      'Pressione a barra de espaço para o Dash pular.';

  @override
  String get gameInstructionsPageCollectEggsAcornsTitle =>
      'Colete Medalhas e Energia';

  @override
  String get gameInstructionsPageCollectEggsAcornsDescription =>
      'Ganhe pontos coletando medalhas e energia ao longo do treino.';

  @override
  String get gameInstructionsPagePowerfulWingsTitle => 'Power-up da Zona 5';

  @override
  String get gameInstructionsPagePowerfulWingsDescription =>
      'Colete a Zona 5 para turbinar o Dash. No ar, toque para fazer um pulo duplo e ver o Dash voar!';

  @override
  String get gameInstructionsPageLevelGatesTitle => 'Treinos';

  @override
  String get gameInstructionsPageLevelGatesDescription =>
      'Avance pelos treinos para enfrentar desafios mais difíceis a cada etapa.';

  @override
  String get gameInstructionsPageAvoidBugsTitle => 'Desvie dos Obstáculos';

  @override
  String get gameInstructionsPageAvoidBugsDescription =>
      'Cuidado com os obstáculos! Pule por cima deles para não perder energia.';

  @override
  String get mobileAppsComingSoon => 'Apps Móveis em Breve';

  @override
  String get mobileAppsComingSoonGrabThe => 'Pegue o ';

  @override
  String get mobileAppsComingSoonMobileSourceCode => 'código-fonte mobile ';

  @override
  String get mobileAppsComingSoonDescription =>
      'no repositório e fique de olho nos apps disponíveis para download nas lojas em breve! Abra este link em um navegador de desktop para jogar hoje.';

  @override
  String get superDash => 'Moovz Dash';

  @override
  String get howItsMade => 'Como foi feito';

  @override
  String get aboutSuperDash => 'Sobre o Moovz Dash';

  @override
  String get learn => 'Saiba ';

  @override
  String get howWeBuiltSuperDash => 'como o jogo foi feito';

  @override
  String get inFlutterAndGrabThe => ' em Flutter e acesse o ';

  @override
  String get openSourceCode => 'código open source do Moovz Dash.';

  @override
  String get otherLinks => 'Outros Links';

  @override
  String get flutterGames => 'Jogos Flutter';

  @override
  String get privacyPolicy => 'Política de Privacidade';

  @override
  String get termsOfService => 'Termos de Uso';

  @override
  String get enter => 'Confirmar';

  @override
  String get nicknameBlacklistedMessage =>
      'Mantenha o respeito, escolha outro apelido';

  @override
  String get inputNicknamePageHeadline => 'Escolha seu apelido para\no ranking';

  @override
  String get nicknameErrorMessage =>
      'Digite um apelido de 3 a 12 caracteres (letras, números ou _)';

  @override
  String get scoreSubmissionErrorMessage =>
      'Houve um erro ao enviar sua pontuação';

  @override
  String get shareYourScore =>
      'Compartilhe sua pontuação no Moovz Dash e desafie seus amigos a ir mais longe!';

  @override
  String get pts => 'pts';

  @override
  String get shareOn => 'Compartilhar em:';

  @override
  String get share => 'Compartilhar';

  @override
  String get seeTheRanking => 'Ver o ranking';

  @override
  String get gameOver => 'Treino encerrado!';

  @override
  String get betterLuckNextTime => 'Na próxima você vai mais longe.';

  @override
  String get totalScore => 'Pontuação Total';

  @override
  String get submitScore => 'Enviar pontuação';

  @override
  String get playAgain => 'Treinar de novo';

  @override
  String gameScoreLabel(int points) {
    return '$points pts';
  }

  @override
  String get leaderboardPageLeaderboardHeadline => 'Ranking';

  @override
  String get leaderboardPageLeaderboardErrorText =>
      'Houve um erro ao carregar o ranking.';

  @override
  String get leaderboardPageLeaderboardNoEntries => 'Nenhum registro';

  @override
  String get leaderboardPageGoBackButton => 'Voltar';

  @override
  String get tapToStart =>
      'Toque/aperte Espaço para começar o treino\nToque para pular, arraste para baixo para deslizar';

  @override
  String get downloadAppMessage =>
      'Faça check-in no Moovz Dash, desvie dos obstáculos, colete medalhas e veja até onde seu treino vai!';

  @override
  String get downloadAppLabel => 'Baixar o app';

  @override
  String get difficultyLabel => 'Dificuldade';

  @override
  String get difficultyEasy => 'Fácil';

  @override
  String get difficultyMedium => 'Médio';

  @override
  String get difficultyHard => 'Difícil';

  @override
  String gameLivesLabel(int lives) {
    return 'Vidas: $lives';
  }

  @override
  String get specialItemMedalName => 'Medalha';

  @override
  String specialItemMedalEffect(int points) {
    return '+$points pontos';
  }

  @override
  String get specialItemZoneFiveName => 'Zona 5';

  @override
  String get specialItemZoneFiveEffect => 'Pulo duplo e proteção';

  @override
  String get specialItemExtraLifeName => 'Vida extra';

  @override
  String get specialItemExtraLifeEffect => '+1 vida';

  @override
  String get bestiaryTitle => 'Inimigos e itens';

  @override
  String get enemyNameCramp => 'Cãibra';

  @override
  String get enemyNameSoreness => 'Dor muscular';

  @override
  String get enemyNameIcePack => 'Bolsa de gelo';

  @override
  String get enemyNameFatigueHourglass => 'Ampulheta da fadiga';

  @override
  String get enemyNameLazyCloud => 'Nuvem preguiçosa';

  @override
  String get enemyNameBandage => 'Bandagem';

  @override
  String get enemyNameLowBar => 'Barra baixa';

  @override
  String get bestiaryEnemiesHeading => 'Inimigos';

  @override
  String get bestiaryItemsHeading => 'Itens';

  @override
  String get itemNameEnergy => 'Energia';
}
