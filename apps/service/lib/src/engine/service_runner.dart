import 'dart:async';

import 'package:ktc_core/ktc_core.dart';

import '../cloud/cloud_sync.dart';
import '../commands/cli.dart' show appVersion;
import '../storage/data_dir.dart';
import 'service_engine.dart';

/// The service main loop: ticks the engine and synchronizes with the cloud.
///
/// Cloud traffic is kept within the free Firestore quota: configuration is
/// read every [syncInterval], only changed usage is uploaded, and the status
/// is reported every [statusInterval] or when the active child changes.
///
/// Synchronization runs alongside the ticks: a slow or hanging network must
/// not pause time accounting (a pause longer than [UsageTracker.maxTickGap]
/// would be free play time).
final class ServiceRunner {
  ServiceRunner({
    required this.engine,
    required this.dir,
    required this.sleep,
    required this.monotonicNow,
    required this.wallClock,
    this.cloud,
    this.tickInterval = const Duration(seconds: 2),
    this.syncInterval = const Duration(minutes: 1),
    this.statusInterval = const Duration(minutes: 5),
    void Function(String message)? log,
  }) : _log = log ?? ((_) {});

  final ServiceEngine engine;
  final DataDir dir;
  final CloudSync? cloud;
  final Future<void> Function(Duration) sleep;
  final Duration Function() monotonicNow;
  final DateTime Function() wallClock;
  final Duration tickInterval;
  final Duration syncInterval;
  final Duration statusInterval;
  final void Function(String message) _log;

  var _stopped = false;
  Duration? _lastSync;
  Duration? _lastStatus;
  String? _reportedChild;
  var _firstSync = true;
  Future<void>? _sync;

  void stop() => _stopped = true;

  Future<void> run() async {
    var last = monotonicNow();
    while (!_stopped) {
      await sleep(tickInterval);
      final now = monotonicNow();
      engine.tick(now - last);
      last = now;
      if (cloud != null &&
          _sync == null &&
          (_lastSync == null || now - _lastSync! >= syncInterval)) {
        _lastSync = now;
        _sync = syncOnce().whenComplete(() => _sync = null);
      }
    }
    _log('Service stopped.');
  }

  /// One synchronization round; network errors are logged and retried next time.
  Future<void> syncOnce() async {
    final cloud = this.cloud;
    if (cloud == null) return;
    try {
      if (await cloud.findFamily() == null) {
        _log(
          'This PC is not in a family (removed by the parent?). Working offline.',
        );
        return;
      }
      final config = await cloud.pullConfig();
      engine.updateConfig(config);
      dir.writeJson(dir.configFile, config.toJson());

      // After a start (or reconnect), upload the whole week once.
      final usage = _firstSync ? _week() : engine.takeDirtyUsage();
      if (_firstSync) engine.takeDirtyUsage();
      await cloud.pushUsage(usage);
      _firstSync = false;

      final now = monotonicNow();
      if (_lastStatus == null ||
          now - _lastStatus! >= statusInterval ||
          _reportedChild != engine.activeChildId) {
        await cloud.reportStatus(
          appVersion: appVersion,
          activeChildId: engine.activeChildId,
          now: wallClock(),
        );
        _lastStatus = now;
        _reportedChild = engine.activeChildId;
      }
      dir.writeJson(dir.cloudFile, cloud.state.toJson());
    } on Exception catch (error) {
      _log('Sync failed (will retry): $error');
    }
  }

  List<DailyUsage> _week() {
    final today = wallClock();
    return dir.usageForDates({
      for (var day = 0; day < 7; day++)
        dateKey(today.subtract(Duration(days: day))),
    });
  }
}
