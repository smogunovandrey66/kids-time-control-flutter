// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kids Time Control';

  @override
  String get firebaseNotConfiguredTitle => 'Firebase is not configured';

  @override
  String get firebaseNotConfiguredBody =>
      'Run `flutterfire configure` in apps/parent to connect the app to your Firebase project. See apps/parent/README.md.';

  @override
  String get signInTitle => 'Screen time for your kids';

  @override
  String get signInDescription =>
      'Sign in to manage children, games and limits on your home PC.';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signOut => 'Sign out';

  @override
  String get createFamilyTitle => 'Create your family';

  @override
  String get createFamilyDescription =>
      'Children, games and computers are shared within a family.';

  @override
  String get familyName => 'Family name';

  @override
  String get createFamily => 'Create';

  @override
  String get tabToday => 'Today';

  @override
  String get tabChildren => 'Children';

  @override
  String get tabGames => 'Games';

  @override
  String get tabComputers => 'Computers';

  @override
  String get todayNoChildren => 'Add a child on the Children tab.';

  @override
  String usedOfLimit(String used, String limit) {
    return '$used of $limit';
  }

  @override
  String remaining(String time) {
    return '$time left';
  }

  @override
  String addMinutes(int minutes) {
    return '+$minutes min';
  }

  @override
  String get bonusAdded => 'Extra time added for today';

  @override
  String get childrenEmpty => 'No children yet.';

  @override
  String get addChild => 'Add child';

  @override
  String get editChild => 'Edit child';

  @override
  String get childName => 'Name';

  @override
  String get pin => 'PIN (4-6 digits)';

  @override
  String get pinHintNew => 'The child enters it on the PC';

  @override
  String get pinHintKeep => 'Leave empty to keep the current PIN';

  @override
  String get weekdayLimit => 'Weekday limit, minutes';

  @override
  String get weekendLimit => 'Weekend limit, minutes';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get errorNameEmpty => 'Enter a name';

  @override
  String get errorNameTooLong => 'The name is too long';

  @override
  String get errorPinInvalid => 'PIN must be 4 to 6 digits';

  @override
  String get errorPinRequired => 'Set a PIN';

  @override
  String get errorLimitInvalid => 'Enter minutes from 0 to 1440';

  @override
  String get gamesEmpty =>
      'No games yet. Add the games your children play on the PC.';

  @override
  String get addGame => 'Add game';

  @override
  String get editGame => 'Game';

  @override
  String get gameName => 'Name';

  @override
  String get exeName => 'Executable name, e.g. RobloxPlayerBeta.exe';

  @override
  String get exePath => 'Full path to the executable';

  @override
  String get commandLineContains => 'Command line contains';

  @override
  String get gameFolder => 'Or any program in the folder';

  @override
  String get gameFolderHint =>
      'Renaming the exe will not help. * is any folder name: C:\\Users\\*\\AppData\\Local\\Roblox';

  @override
  String get matchHint =>
      'Fill in at least one field. `ktc processes` on the PC shows the values.';

  @override
  String get errorNoCriteria => 'Fill in at least one of the fields';

  @override
  String get computersEmpty =>
      'No computers yet. Pair the PC your children use.';

  @override
  String get pairComputer => 'Pair computer';

  @override
  String get pairingCodeLabel => 'Code from the PC';

  @override
  String get pairingHint =>
      'Run `ktc pair` on the PC and enter the code it shows.';

  @override
  String get pair => 'Pair';

  @override
  String get cancel => 'Cancel';

  @override
  String get paired => 'Computer paired';

  @override
  String get pairingNotFound => 'Code not found or expired';

  @override
  String get pairingInvalid => 'A code has 8 characters';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String lastSeen(String time) {
    return 'Last seen $time';
  }

  @override
  String get neverSeen => 'Has not connected yet';

  @override
  String get removeComputer => 'Remove';

  @override
  String get weekTitle => 'Last 7 days';

  @override
  String errorGeneric(String message) {
    return 'Something went wrong: $message';
  }

  @override
  String get pickFromPc => 'Pick from programs on the PC';

  @override
  String get pickFromPcHint =>
      'What ran on your computers in the last two weeks, most used first';

  @override
  String get programsEmpty =>
      'Nothing yet. The list fills in as the PC is used (updated every 5 minutes).';

  @override
  String programUsage(String time, String devices) {
    return '$time in 2 weeks · $devices';
  }

  @override
  String alreadyGame(String name) {
    return 'Already a game: $name';
  }

  @override
  String foundOnPc(String path) {
    return 'Found on the PC: $path';
  }

  @override
  String get adminWarningTitle => 'Children can turn off the control';

  @override
  String adminWarning(String device) {
    return 'On $device, the Windows account at the screen is an administrator. Create a standard (non-administrator) account for the children and keep the administrator password to yourself.';
  }
}
