import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import 'game_state.dart';

/// Feeds walking into [GameState].
///
/// The phone's own health store does the counting, all day, even when the
/// app is closed:
///  * iPhone: Apple Health.
///  * Android: Health Connect (where Google Fit, Samsung Health, the phone's
///    step counter etc. write). If Health Connect isn't on the phone, the
///    hardware step sensor is used instead.
///
/// The system asks the player once for permission (required by Apple and
/// Google); after that the game simply shows "your steps".
class StepService with WidgetsBindingObserver {
  StepService(this.game);

  final GameState game;
  final _health = Health();
  StreamSubscription<StepCount>? _sensorSub;
  Timer? _poll;
  bool _healthReady = false;

  List<HealthDataType> get _types => [
        HealthDataType.STEPS,
        Platform.isIOS ? HealthDataType.DISTANCE_WALKING_RUNNING : HealthDataType.DISTANCE_DELTA,
      ];

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      // A browser can't read steps: the website uses the demo buttons.
      game.setStepSensorMissing();
      return;
    }
    try {
      await _health.configure();
      if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
        await _startSensor();
        return;
      }
      _healthReady = await _health.requestAuthorization(
        _types,
        permissions: [HealthDataAccess.READ, HealthDataAccess.READ],
      );
      if (!_healthReady) {
        // Player said no: Android can still use the step sensor.
        if (Platform.isAndroid) {
          await _startSensor();
        } else {
          game.setStepSensorMissing();
        }
        return;
      }
      if (Platform.isAndroid) {
        // Lets the step total keep updating while the app is in the background.
        try {
          await _health.requestHealthDataInBackgroundAuthorization();
        } catch (_) {}
      }
      await _readToday();
      _poll = Timer.periodic(const Duration(seconds: 30), (_) => _readToday());
      // Android: start hardware pedometer as parallel stream if available
      if (Platform.isAndroid) {
        _startSensor();
      }
    } catch (e) {
      debugPrint('StepService health init error: $e');
      if (!kIsWeb && Platform.isAndroid) {
        await _startSensor();
      } else {
        game.setStepSensorMissing();
      }
    }
  }

  /// Today's totals since midnight, straight from the health store.
  Future<void> _readToday() async {
    if (!_healthReady) return;
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final steps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;
      final points = await _health.getHealthDataFromTypes(
        types: [_types[1]],
        startTime: midnight,
        endTime: now,
      );
      var meters = 0.0;
      for (final p in _health.removeDuplicates(points)) {
        final v = p.value;
        if (v is NumericHealthValue) meters += v.numericValue.toDouble();
      }
      // Some phones log steps but no distance: estimate from steps then.
      final km = meters > 0 ? meters / 1000 : steps * GameState.strideMeters / 1000;
      if (steps == 0 && meters == 0) {
        // Nothing logged yet today (or a simulator with no health data).
        game.setStepSensorMissing();
      }
      game.onHealthToday(km: km, steps: steps);
    } catch (e) {
      debugPrint('Health read failed: $e');
    }
  }

  Future<void> _startSensor() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      game.setStepSensorMissing();
      return;
    }
    _sensorSub = Pedometer.stepCountStream.listen(
      (event) => game.onStepCounter(event.steps),
      onError: (_) => game.setStepSensorMissing(),
      cancelOnError: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readToday();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _sensorSub?.cancel();
  }
}
