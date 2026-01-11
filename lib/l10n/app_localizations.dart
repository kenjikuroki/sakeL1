import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('es'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Sake Exam L1'**
  String get appTitle;

  /// Title shown on the home screen
  ///
  /// In en, this message translates to:
  /// **'Sake Exam L1: Study & Quiz'**
  String get homeTitle;

  /// Subtitle shown on the home screen
  ///
  /// In en, this message translates to:
  /// **'Master Sake knowledge in your spare time!'**
  String get homeSubtitle;

  /// Title for Part 1
  ///
  /// In en, this message translates to:
  /// **'Ingredients & Basics'**
  String get part1Title;

  /// Title for Part 2
  ///
  /// In en, this message translates to:
  /// **'Categories & Grades'**
  String get part2Title;

  /// Title for Part 3
  ///
  /// In en, this message translates to:
  /// **'Service & Storage'**
  String get part3Title;

  /// Button text to review incorrect answers
  ///
  /// In en, this message translates to:
  /// **'Review Weakness'**
  String get reviewWeakness;

  /// Message shown when the answer is correct
  ///
  /// In en, this message translates to:
  /// **'Correct! ⭕'**
  String get correct;

  /// Message shown when the answer is incorrect
  ///
  /// In en, this message translates to:
  /// **'Incorrect... ❌'**
  String get incorrect;

  /// Label for the question number
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get questionLabel;

  /// Title for the result screen
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get resultTitle;

  /// Button text to go back to home
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// Loading text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Message shown when no data is found
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// Message shown when score is perfect
  ///
  /// In en, this message translates to:
  /// **'PERFECT! 🎉'**
  String get perfectMessage;

  /// Message shown when score is passing
  ///
  /// In en, this message translates to:
  /// **'Great job! You passed!'**
  String get passMessage;

  /// Message shown when score is failing
  ///
  /// In en, this message translates to:
  /// **'Almost! Let\'s review.'**
  String get failMessage;

  /// Label for image questions
  ///
  /// In en, this message translates to:
  /// **'Image Question'**
  String get imageQuestion;

  /// Button to review mistakes
  ///
  /// In en, this message translates to:
  /// **'Review Mistakes'**
  String get reviewMistakes;

  /// Button to retry the quiz
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Label for the score
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get scoreLabel;
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
