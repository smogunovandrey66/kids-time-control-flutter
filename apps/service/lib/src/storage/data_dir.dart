import 'dart:convert';
import 'dart:io';

import 'package:ktc_core/ktc_core.dart';

/// Files of the PC program:
///
/// ```
/// <data dir>/config.json            children and games (from the cloud or edited by hand)
/// <data dir>/cloud.json             Firebase project, anonymous session, family id
/// <data dir>/usage/<child>_<date>.json
/// ```
///
/// The service uses `%ProgramData%\KidsTimeControl`, writable only by SYSTEM and administrators.
final class DataDir {
  DataDir(this.path);

  static String defaultPath() => Platform.isWindows
      ? '${Platform.environment['ProgramData'] ?? r'C:\ProgramData'}\\KidsTimeControl'
      : '${Directory.current.path}/.ktc';

  final String path;

  File get configFile => File('$path/config.json');

  File get cloudFile => File('$path/cloud.json');

  Directory get usageDir => Directory('$path/usage');

  Map<String, Object?>? readJson(File file) => file.existsSync()
      ? jsonDecode(file.readAsStringSync()) as Map<String, Object?>
      : null;

  void writeJson(File file, Map<String, Object?> json) {
    file.parent.createSync(recursive: true);
    // Write-then-rename, so a power cut never leaves a half-written file.
    final temp = File('${file.path}.tmp')
      ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    temp.renameSync(file.path);
  }

  DailyUsage loadUsage(String childId, String date) {
    final json = readJson(
      File('${usageDir.path}/${DailyUsage.documentId(childId, date)}.json'),
    );
    return json == null
        ? DailyUsage(childId: childId, date: date, totalSeconds: 0)
        : DailyUsage.fromJson(json);
  }

  void saveUsage(DailyUsage usage) => writeJson(
    File(
      '${usageDir.path}/${DailyUsage.documentId(usage.childId, usage.date)}.json',
    ),
    usage.toJson(),
  );

  /// Usage records of the given dates (e.g. the last week), for uploading.
  List<DailyUsage> usageForDates(Set<String> dates) {
    if (!usageDir.existsSync()) return const [];
    return [
      for (final file in usageDir.listSync().whereType<File>())
        if (file.path.endsWith('.json'))
          if (DailyUsage.fromJson(readJson(file)!) case final usage
              when dates.contains(usage.date))
            usage,
    ];
  }
}
