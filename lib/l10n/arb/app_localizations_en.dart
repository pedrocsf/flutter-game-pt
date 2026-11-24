// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get gameIntroPageHeadline =>
      'Check in to Moovz Dash, dodge the obstacles, collect medals, and see how far your workout takes you!';

  @override
  String get gameIntroPagePlayButtonText => 'Play';

  @override
  String get gameInstructionsPageAutoRunTitle => 'Dash Auto-runs';

  @override
  String get gameInstructionsPageAutoRunDescription =>
      'Welcome to Moovz Dash. In this workout, Dash runs automatically.';

  @override
  String get gameInstructionsPageTapToJumpTitle => 'Tap to Jump';

  @override
  String get gameInstructionsPageTapToJumpDescription =>
      'Tap the screen to make Dash jump.';

  @override
  String get gameInstructionsPageTapToJumpDescriptionDesktop =>
      'Press spacebar to make Dash jump.';

  @override
  String get gameInstructionsPageCollectEggsAcornsTitle =>
      'Collect Medals & Energy';

  @override
  String get gameInstructionsPageCollectEggsAcornsDescription =>
      'Earn points by collecting medals and energy along your workout.';

  @override
  String get gameInstructionsPagePowerfulWingsTitle => 'Zone 5 Power-Up';

  @override
  String get gameInstructionsPagePowerfulWingsDescription =>
      'Collect Zone 5 to power up Dash. While in midair, tap to do a double jump and see Dash fly!';

  @override
  String get gameInstructionsPageLevelGatesTitle => 'Workouts';

  @override
  String get gameInstructionsPageLevelGatesDescription =>
      'Move through the workouts to face tougher challenges at each stage.';

  @override
  String get gameInstructionsPageAvoidBugsTitle => 'Avoid Obstacles';

  @override
  String get gameInstructionsPageAvoidBugsDescription =>
      'Watch out for obstacles! Jump over them to avoid losing energy.';

  @override
  String get mobileAppsComingSoon => 'Mobile Apps Coming Soon';

  @override
  String get mobileAppsComingSoonGrabThe => 'Grab the ';

  @override
  String get mobileAppsComingSoonMobileSourceCode => 'mobile source code ';

  @override
  String get mobileAppsComingSoonDescription =>
      'in the repo and look for the apps available for download in stores soon! Open this link on a desktop web browser to play today.';

  @override
  String get superDash => 'Moovz Dash';

  @override
  String get howItsMade => 'How it\'s made';

  @override
  String get aboutSuperDash => 'About Moovz Dash';

  @override
  String get learn => 'Learn ';

  @override
  String get howWeBuiltSuperDash => 'how we built Moovz Dash';

  @override
  String get inFlutterAndGrabThe => ' in Flutter and grab the ';

  @override
  String get openSourceCode => 'open source code.';

  @override
  String get otherLinks => 'Other Links';

  @override
  String get flutterGames => 'Flutter Games';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get enter => 'Enter';

  @override
  String get nicknameBlacklistedMessage =>
      'Keep it respectful, choose another nickname';

  @override
  String get inputNicknamePageHeadline =>
      'Choose your nickname for\nthe ranking';

  @override
  String get nicknameErrorMessage =>
      'Enter a nickname with 3 to 12 characters (letters, numbers or _)';

  @override
  String get scoreSubmissionErrorMessage =>
      'There was an error submitting your score';

  @override
  String get shareYourScore =>
      'Share your Moovz Dash score and challenge your friends to go further!';

  @override
  String get pts => 'Pts';

  @override
  String get shareOn => 'Share on:';

  @override
  String get share => 'Share';

  @override
  String get seeTheRanking => 'See the ranking';

  @override
  String get gameOver => 'Workout over!';

  @override
  String get betterLuckNextTime => 'Better luck next time.';

  @override
  String get totalScore => 'Total Score';

  @override
  String get submitScore => 'Submit score';

  @override
  String get playAgain => 'Train again';

  @override
  String gameScoreLabel(int points) {
    return '$points Pts';
  }

  @override
  String get leaderboardPageLeaderboardHeadline => 'Ranking';

  @override
  String get leaderboardPageLeaderboardErrorText =>
      'There was an error while fetching the ranking.';

  @override
  String get leaderboardPageLeaderboardNoEntries => 'No entries';

  @override
  String get leaderboardPageGoBackButton => 'Go back';

  @override
  String get tapToStart =>
      'Tap/press Space to start your workout\nTap to jump, swipe down to slide';

  @override
  String get downloadAppMessage =>
      'Check in to Moovz Dash, dodge the obstacles, collect medals, and see how far your workout takes you!';

  @override
  String get downloadAppLabel => 'Download the app';

  @override
  String get difficultyLabel => 'Difficulty';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String gameLivesLabel(int lives) {
    return 'Lives: $lives';
  }

  @override
  String get specialItemMedalName => 'Medal';

  @override
  String specialItemMedalEffect(int points) {
    return '+$points points';
  }

  @override
  String get specialItemZoneFiveName => 'Zone 5';

  @override
  String get specialItemZoneFiveEffect => 'Double jump and protection';

  @override
  String get specialItemExtraLifeName => 'Extra life';

  @override
  String get specialItemExtraLifeEffect => '+1 life';

  @override
  String get bestiaryTitle => 'Enemies and items';

  @override
  String get enemyNameCramp => 'Cramp';

  @override
  String get enemyNameSoreness => 'Muscle soreness';

  @override
  String get enemyNameIcePack => 'Ice pack';

  @override
  String get enemyNameFatigueHourglass => 'Fatigue hourglass';

  @override
  String get enemyNameLazyCloud => 'Lazy cloud';

  @override
  String get enemyNameBandage => 'Bandage';

  @override
  String get enemyNameLowBar => 'Low bar';

  @override
  String get bestiaryEnemiesHeading => 'Enemies';

  @override
  String get bestiaryItemsHeading => 'Items';

  @override
  String get itemNameEnergy => 'Energy';
}
