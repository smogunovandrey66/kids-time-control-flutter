// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Kids Time Control';

  @override
  String get firebaseNotConfiguredTitle => 'Firebase не настроен';

  @override
  String get firebaseNotConfiguredBody =>
      'Выполните `flutterfire configure` в apps/parent, чтобы подключить приложение к своему проекту Firebase. Подробности — в apps/parent/README.md.';

  @override
  String get signInTitle => 'Время за играми под контролем';

  @override
  String get signInDescription =>
      'Войдите, чтобы управлять детьми, играми и лимитами на домашнем ПК.';

  @override
  String get signInWithGoogle => 'Войти через Google';

  @override
  String get signOut => 'Выйти';

  @override
  String get createFamilyTitle => 'Создайте семью';

  @override
  String get createFamilyDescription =>
      'Дети, игры и компьютеры объединяются в семью.';

  @override
  String get familyName => 'Название семьи';

  @override
  String get createFamily => 'Создать';

  @override
  String get tabToday => 'Сегодня';

  @override
  String get tabChildren => 'Дети';

  @override
  String get tabGames => 'Игры';

  @override
  String get tabComputers => 'Компьютеры';

  @override
  String get todayNoChildren => 'Добавьте ребёнка на вкладке «Дети».';

  @override
  String usedOfLimit(String used, String limit) {
    return '$used из $limit';
  }

  @override
  String remaining(String time) {
    return 'Осталось $time';
  }

  @override
  String addMinutes(int minutes) {
    return '+$minutes мин';
  }

  @override
  String get bonusAdded => 'Время на сегодня добавлено';

  @override
  String get childrenEmpty => 'Детей пока нет.';

  @override
  String get addChild => 'Добавить ребёнка';

  @override
  String get editChild => 'Ребёнок';

  @override
  String get childName => 'Имя';

  @override
  String get pin => 'PIN (4–6 цифр)';

  @override
  String get pinHintNew => 'Ребёнок вводит его на ПК';

  @override
  String get pinHintKeep => 'Оставьте пустым, чтобы не менять';

  @override
  String get weekdayLimit => 'Лимит в будни, минут';

  @override
  String get weekendLimit => 'Лимит в выходные, минут';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get errorNameEmpty => 'Введите имя';

  @override
  String get errorNameTooLong => 'Слишком длинное имя';

  @override
  String get errorPinInvalid => 'PIN — от 4 до 6 цифр';

  @override
  String get errorPinRequired => 'Задайте PIN';

  @override
  String get errorLimitInvalid => 'Введите минуты от 0 до 1440';

  @override
  String get gamesEmpty =>
      'Игр пока нет. Добавьте игры, в которые дети играют на ПК.';

  @override
  String get addGame => 'Добавить игру';

  @override
  String get editGame => 'Игра';

  @override
  String get gameName => 'Название';

  @override
  String get exeName => 'Имя exe, например RobloxPlayerBeta.exe';

  @override
  String get exePath => 'Полный путь к exe';

  @override
  String get commandLineContains => 'Командная строка содержит';

  @override
  String get matchHint =>
      'Заполните хотя бы одно поле. Значения показывает `ktc processes` на ПК.';

  @override
  String get errorNoCriteria => 'Заполните хотя бы одно из полей';

  @override
  String get computersEmpty =>
      'Компьютеров пока нет. Привяжите ПК, за которым играют дети.';

  @override
  String get pairComputer => 'Привязать компьютер';

  @override
  String get pairingCodeLabel => 'Код с компьютера';

  @override
  String get pairingHint =>
      'Запустите на ПК `ktc pair` и введите показанный код.';

  @override
  String get pair => 'Привязать';

  @override
  String get cancel => 'Отмена';

  @override
  String get paired => 'Компьютер привязан';

  @override
  String get pairingNotFound => 'Код не найден или устарел';

  @override
  String get pairingInvalid => 'Код состоит из 8 символов';

  @override
  String get online => 'На связи';

  @override
  String get offline => 'Не на связи';

  @override
  String lastSeen(String time) {
    return 'Был на связи $time';
  }

  @override
  String get neverSeen => 'Ещё не подключался';

  @override
  String get removeComputer => 'Отвязать';

  @override
  String get weekTitle => 'Последние 7 дней';

  @override
  String errorGeneric(String message) {
    return 'Что-то пошло не так: $message';
  }
}
