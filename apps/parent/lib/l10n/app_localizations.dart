import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Kids Time Control'**
  String get appTitle;

  /// No description provided for @firebaseNotConfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'Firebase is not configured'**
  String get firebaseNotConfiguredTitle;

  /// No description provided for @firebaseNotConfiguredBody.
  ///
  /// In en, this message translates to:
  /// **'Run `flutterfire configure` in apps/parent to connect the app to your Firebase project. See apps/parent/README.md.'**
  String get firebaseNotConfiguredBody;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen time for your kids'**
  String get signInTitle;

  /// No description provided for @signInDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage children, games and limits on your home PC.'**
  String get signInDescription;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @createFamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your family'**
  String get createFamilyTitle;

  /// No description provided for @createFamilyDescription.
  ///
  /// In en, this message translates to:
  /// **'Children, games and computers are shared within a family.'**
  String get createFamilyDescription;

  /// No description provided for @familyName.
  ///
  /// In en, this message translates to:
  /// **'Family name'**
  String get familyName;

  /// No description provided for @createFamily.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createFamily;

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabChildren.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get tabChildren;

  /// No description provided for @tabGames.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get tabGames;

  /// No description provided for @tabComputers.
  ///
  /// In en, this message translates to:
  /// **'Computers'**
  String get tabComputers;

  /// No description provided for @todayNoChildren.
  ///
  /// In en, this message translates to:
  /// **'Add a child on the Children tab.'**
  String get todayNoChildren;

  /// No description provided for @usedOfLimit.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit}'**
  String usedOfLimit(String used, String limit);

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String remaining(String time);

  /// No description provided for @addMinutes.
  ///
  /// In en, this message translates to:
  /// **'+{minutes} min'**
  String addMinutes(int minutes);

  /// No description provided for @bonusAdded.
  ///
  /// In en, this message translates to:
  /// **'Extra time added for today'**
  String get bonusAdded;

  /// No description provided for @childrenEmpty.
  ///
  /// In en, this message translates to:
  /// **'No children yet.'**
  String get childrenEmpty;

  /// No description provided for @addChild.
  ///
  /// In en, this message translates to:
  /// **'Add child'**
  String get addChild;

  /// No description provided for @editChild.
  ///
  /// In en, this message translates to:
  /// **'Edit child'**
  String get editChild;

  /// No description provided for @childName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get childName;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'PIN (4-6 digits)'**
  String get pin;

  /// No description provided for @pinHintNew.
  ///
  /// In en, this message translates to:
  /// **'The child enters it on the PC'**
  String get pinHintNew;

  /// No description provided for @pinHintKeep.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep the current PIN'**
  String get pinHintKeep;

  /// No description provided for @weekdayLimit.
  ///
  /// In en, this message translates to:
  /// **'Weekday limit, minutes'**
  String get weekdayLimit;

  /// No description provided for @weekendLimit.
  ///
  /// In en, this message translates to:
  /// **'Weekend limit, minutes'**
  String get weekendLimit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @errorNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get errorNameEmpty;

  /// No description provided for @errorNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'The name is too long'**
  String get errorNameTooLong;

  /// No description provided for @errorPinInvalid.
  ///
  /// In en, this message translates to:
  /// **'PIN must be 4 to 6 digits'**
  String get errorPinInvalid;

  /// No description provided for @errorPinRequired.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN'**
  String get errorPinRequired;

  /// No description provided for @errorLimitInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter minutes from 0 to 1440'**
  String get errorLimitInvalid;

  /// No description provided for @gamesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No games yet. Add the games your children play on the PC.'**
  String get gamesEmpty;

  /// No description provided for @addGame.
  ///
  /// In en, this message translates to:
  /// **'Add game'**
  String get addGame;

  /// No description provided for @editGame.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get editGame;

  /// No description provided for @gameName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get gameName;

  /// No description provided for @exeName.
  ///
  /// In en, this message translates to:
  /// **'Executable name, e.g. RobloxPlayerBeta.exe'**
  String get exeName;

  /// No description provided for @exePath.
  ///
  /// In en, this message translates to:
  /// **'Full path to the executable'**
  String get exePath;

  /// No description provided for @commandLineContains.
  ///
  /// In en, this message translates to:
  /// **'Command line contains'**
  String get commandLineContains;

  /// No description provided for @gameFolder.
  ///
  /// In en, this message translates to:
  /// **'Or any program in the folder'**
  String get gameFolder;

  /// No description provided for @gameFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Renaming the exe will not help. * is any folder name: C:\\Users\\*\\AppData\\Local\\Roblox'**
  String get gameFolderHint;

  /// No description provided for @matchHint.
  ///
  /// In en, this message translates to:
  /// **'Fill in at least one field. `ktc processes` on the PC shows the values.'**
  String get matchHint;

  /// No description provided for @errorNoCriteria.
  ///
  /// In en, this message translates to:
  /// **'Fill in at least one of the fields'**
  String get errorNoCriteria;

  /// No description provided for @computersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No computers yet. Pair the PC your children use.'**
  String get computersEmpty;

  /// No description provided for @pairComputer.
  ///
  /// In en, this message translates to:
  /// **'Pair computer'**
  String get pairComputer;

  /// No description provided for @pairingCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code from the PC'**
  String get pairingCodeLabel;

  /// No description provided for @pairingHint.
  ///
  /// In en, this message translates to:
  /// **'Run `ktc pair` on the PC and enter the code it shows.'**
  String get pairingHint;

  /// No description provided for @pair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get pair;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @paired.
  ///
  /// In en, this message translates to:
  /// **'Computer paired'**
  String get paired;

  /// No description provided for @pairingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Code not found or expired'**
  String get pairingNotFound;

  /// No description provided for @pairingInvalid.
  ///
  /// In en, this message translates to:
  /// **'A code has 8 characters'**
  String get pairingInvalid;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {time}'**
  String lastSeen(String time);

  /// No description provided for @neverSeen.
  ///
  /// In en, this message translates to:
  /// **'Has not connected yet'**
  String get neverSeen;

  /// No description provided for @removeComputer.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeComputer;

  /// No description provided for @weekTitle.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get weekTitle;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {message}'**
  String errorGeneric(String message);

  /// No description provided for @pickFromPc.
  ///
  /// In en, this message translates to:
  /// **'Pick from programs on the PC'**
  String get pickFromPc;

  /// No description provided for @pickFromPcHint.
  ///
  /// In en, this message translates to:
  /// **'What ran on your computers in the last two weeks, most used first'**
  String get pickFromPcHint;

  /// No description provided for @programsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. The list fills in as the PC is used (updated every 5 minutes).'**
  String get programsEmpty;

  /// No description provided for @programUsage.
  ///
  /// In en, this message translates to:
  /// **'{time} in 2 weeks · {devices}'**
  String programUsage(String time, String devices);

  /// No description provided for @alreadyGame.
  ///
  /// In en, this message translates to:
  /// **'Already a game: {name}'**
  String alreadyGame(String name);

  /// No description provided for @foundOnPc.
  ///
  /// In en, this message translates to:
  /// **'Found on the PC: {path}'**
  String foundOnPc(String path);

  /// No description provided for @adminWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Children can turn off the control'**
  String get adminWarningTitle;

  /// No description provided for @adminWarning.
  ///
  /// In en, this message translates to:
  /// **'On {device}, the Windows account at the screen is an administrator. Create a standard (non-administrator) account for the children and keep the administrator password to yourself.'**
  String adminWarning(String device);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
