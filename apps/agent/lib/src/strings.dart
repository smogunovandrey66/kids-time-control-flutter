import 'package:ktc_core/ktc_core.dart';

/// Texts of the agent in Russian and English (picked by the Windows language).
sealed class Strings {
  const Strings();

  factory Strings.forLocale(String localeName) =>
      localeName.toLowerCase().startsWith('ru')
      ? const RussianStrings()
      : const EnglishStrings();

  String get title;
  String whoIsPlaying(String appName);
  String get pin;
  String get play;
  String get cancel;
  String get ok;
  String loginError(LoginError error);
  String notice(Notice notice);
  String get connecting;
  String get nobodyPlaying;
  String playing(String childName, int minutes);
  String get logout;
  String minutes(int count);

  /// Subtitle under the child's name in the "Who is playing?" window.
  /// [seconds] is the time left today; `null` when the service could not tell.
  String? remainingToday(int? seconds);
}

final class RussianStrings extends Strings {
  const RussianStrings();

  @override
  String get title => 'Контроль времени';

  @override
  String whoIsPlaying(String appName) => 'Кто играет в $appName?';

  @override
  String get pin => 'PIN';

  @override
  String get play => 'Играть';

  @override
  String get cancel => 'Отмена';

  @override
  String get ok => 'Понятно';

  @override
  String loginError(LoginError error) => switch (error) {
    LoginError.wrongPin => 'Неверный PIN',
    LoginError.locked =>
      'Слишком много неверных попыток. Попробуйте через 5 минут.',
    LoginError.noTimeLeft => 'На сегодня время закончилось',
  };

  @override
  String notice(Notice notice) => switch (notice.kind) {
    NoticeKind.minutesLeft =>
      '${notice.childName}, осталось ${minutes(notice.minutes)}',
    NoticeKind.timeUp =>
      '${notice.childName}, время вышло. Сохранитесь: игра скоро закроется.',
    NoticeKind.noTimeLeft =>
      '${notice.childName}, на сегодня время закончилось.',
  };

  @override
  String get connecting => 'Нет связи со службой контроля';

  @override
  String get nobodyPlaying => 'Никто не играет';

  @override
  String playing(String childName, int minutes) =>
      'Играет $childName, осталось ${this.minutes(minutes)}';

  @override
  String get logout => 'Выйти (сменить игрока)';

  @override
  String minutes(int count) {
    final lastTwo = count % 100;
    final last = count % 10;
    final word = lastTwo >= 11 && lastTwo <= 14
        ? 'минут'
        : last == 1
        ? 'минута'
        : last >= 2 && last <= 4
        ? 'минуты'
        : 'минут';
    return '$count $word';
  }

  @override
  String? remainingToday(int? seconds) {
    if (seconds == null) return null;
    if (seconds <= 0) return 'На сегодня время закончилось';
    final m = seconds ~/ 60, s = seconds % 60;
    return 'Осталось сегодня $m:${s.toString().padLeft(2, '0')}';
  }
}

final class EnglishStrings extends Strings {
  const EnglishStrings();

  @override
  String get title => 'Kids Time Control';

  @override
  String whoIsPlaying(String appName) => 'Who is playing $appName?';

  @override
  String get pin => 'PIN';

  @override
  String get play => 'Play';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String loginError(LoginError error) => switch (error) {
    LoginError.wrongPin => 'Wrong PIN',
    LoginError.locked => 'Too many wrong attempts. Try again in 5 minutes.',
    LoginError.noTimeLeft => 'No time left today',
  };

  @override
  String notice(Notice notice) => switch (notice.kind) {
    NoticeKind.minutesLeft =>
      '${notice.childName}, ${minutes(notice.minutes)} left',
    NoticeKind.timeUp =>
      '${notice.childName}, time is up. Save your game: it will close soon.',
    NoticeKind.noTimeLeft => '${notice.childName}, no time left today.',
  };

  @override
  String get connecting => 'No connection to the control service';

  @override
  String get nobodyPlaying => 'Nobody is playing';

  @override
  String playing(String childName, int minutes) =>
      '$childName is playing, ${this.minutes(minutes)} left';

  @override
  String get logout => 'Log out (switch player)';

  @override
  String minutes(int count) => count == 1 ? '1 minute' : '$count minutes';

  @override
  String? remainingToday(int? seconds) {
    if (seconds == null) return null;
    if (seconds <= 0) return 'No time left today';
    final m = seconds ~/ 60, s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')} left today';
  }
}
