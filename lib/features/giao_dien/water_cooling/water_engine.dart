import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'water_config.dart';
import 'liquid_physics.dart';
import 'liquid_surface.dart';
import 'water_motion_input.dart';
import 'liquid_optics.dart';

enum WaterEvent {
  tap,
  day,
  pump,
  success,
  warning,
  mechanical,
  activation,
  illumination,
}

class WaterEngine extends ChangeNotifier {
  WaterEngine(this.config);
  static WaterEngine? active;
  static void feedback(WaterEvent e) => active?.trigger(e);
  static Future<void>? _warmup;
  static ui.FragmentProgram? reservoirProgram, rgbProgram;
  static Future<void> warmup() => _warmup ??= () async {
    try {
      final p = await Future.wait([
        ui.FragmentProgram.fromAsset('shaders/water_reservoir.frag'),
        ui.FragmentProgram.fromAsset('shaders/water_argb.frag'),
      ]);
      reservoirProgram = p[0];
      rgbProgram = p[1];
    } on Object {
      _warmup = null;
      rethrow;
    }
  }();
  ui.FragmentShader? reservoirShader, rgbShader;
  void prepareShaders() {
    if (_disposed) return;
    reservoirShader ??= reservoirProgram?.fragmentShader();
    rgbShader ??= rgbProgram?.fragmentShader();
  }

  WaterConfig config;
  late final physics = LiquidPhysics();
  late final surface = LiquidSurface();
  final motion = WaterMotionInput();
  final optics = LiquidOptics();
  bool _suspended = false, _pendingGravity = false;
  double _resumeWait = 0;
  bool get restoring => _pendingGravity;

  void suspend() {
    _suspended = true;
    physics.clearAcceleration();
    motion.reset();
    _remainder = 0;
  }

  void resume() {
    _suspended = false;
    _pendingGravity = true;
    _resumeWait = 0;
    physics.clearAcceleration();
    motion.reset();
    _resetInterpolation();
  }

  static const _physicsStep = 1 / 120;
  double _remainder = 0;
  bool _historyReady = false;
  late final _previousX = Float64List(LiquidPhysics.capacity);
  late final _previousY = Float64List(LiquidPhysics.capacity);
  late final _renderX = Float64List(LiquidPhysics.capacity);
  late final _renderY = Float64List(LiquidPhysics.capacity);
  int surfaceFrame = -1;

  void _resetInterpolation() {
    _previousX.setRange(0, physics.count, physics.x);
    _previousY.setRange(0, physics.count, physics.y);
    _remainder = 0;
    _historyReady = true;
    surfaceFrame = -1;
  }

  void setViewport(double value) {
    if ((aspect - value).abs() < .01 && physics.count > 0) return;
    aspect = value;
    physics.configure(config.fill, aspect, reduced: config.reduced);
    _resetInterpolation();
  }

  void rebuildSurface() {
    if (surfaceFrame == frame) return;
    if (!_historyReady) _resetInterpolation();
    final alpha = (_remainder / _physicsStep).clamp(0.0, 1.0);
    for (var i = 0; i < physics.count; i++) {
      _renderX[i] = _previousX[i] + (physics.x[i] - _previousX[i]) * alpha;
      _renderY[i] = _previousY[i] + (physics.y[i] - _previousY[i]) * alpha;
    }
    surface.rebuild(physics, positionX: _renderX, positionY: _renderY);
    surfaceFrame = frame;
  }

  StreamSubscription<dynamic>? _sensor;
  bool sensorAvailable = false, pumping = false, _disposed = false;
  double seconds = 0, eventAge = 20, aspect = .5;
  int frame = 0, _sensorEpoch = 0;
  WaterEvent event = WaterEvent.activation;
  Offset tapPosition = Offset.zero;
  final blocks = <Object, (Rect, int)>{};
  void update(WaterConfig value) {
    if (config.fill != value.fill || config.reduced != value.reduced) {
      physics.configure(value.fill, aspect, reduced: value.reduced);
      _resetInterpolation();
    }
    config = value;
    notifyListeners();
  }

  void trigger(WaterEvent value) {
    event = value;
    eventAge = 0;
    if (value == WaterEvent.pump) pumping = true;
    if (value == WaterEvent.success || value == WaterEvent.warning)
      pumping = false;
    if (value == WaterEvent.day || value == WaterEvent.pump)
      physics.impulse(.22);
    notifyListeners();
  }

  void tick(double dt) {
    if (_suspended || !dt.isFinite || dt <= 0) return;
    dt = dt.clamp(0, .05);
    frame++;
    seconds += dt;
    eventAge += dt;
    physics.configure(config.fill, aspect, reduced: config.reduced);
    if (_pendingGravity) {
      _resumeWait += dt;
      if (motion.active) {
        physics.gravity(motion.gx, motion.gy, motion.gz);
      } else if (!config.tilt || config.reduced || _resumeWait >= .2) {
        physics.gravity(0, 9.81);
      } else {
        notifyListeners();
        return;
      }
      physics.settleAfterSuspension();
      _resetInterpolation();
      _pendingGravity = false;
    }
    if (!_historyReady) _resetInterpolation();
    _remainder += dt;
    // A fixed 120 Hz simulation avoids alternating 2/3 solver substeps when
    // vsync jitters around 16.67 ms. Interpolate for each display frame instead
    // of showing duplicate states on 90/144 Hz displays. Catch-up is bounded.
    while (_remainder + 1e-10 >= _physicsStep) {
      if (motion.active) {
        motion.advance(_physicsStep);
        physics.gravity(motion.gx, motion.gy, motion.gz);
        physics.acceleration(motion.ax, motion.ay);
      }
      _previousX.setRange(0, physics.count, physics.x);
      _previousY.setRange(0, physics.count, physics.y);
      physics.step(
        _physicsStep,
        fill: config.fill,
        viscosity: config.viscosity,
        aspect: aspect,
        reduced: config.reduced,
      );
      _remainder -= _physicsStep;
    }
    if (_remainder < 0) _remainder = 0;
    optics.advance(dt, physics.meanVx, physics.meanVy, physics.kineticEnergy);
    notifyListeners();
  }

  Future<void> sensors(bool enabled) async {
    final epoch = ++_sensorEpoch;
    final old = _sensor;
    _sensor = null;
    sensorAvailable = false;
    motion.reset();
    physics.clearAcceleration();
    await old?.cancel();
    if (_disposed || epoch != _sensorEpoch) return;
    if (!enabled ||
        !config.tilt ||
        config.reduced ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      physics.gravity(0, 9.81);
      return;
    }
    _sensor = const EventChannel('better_phenikaa/water_gravity')
        .receiveBroadcastStream()
        .listen(
          (v) {
            if (_disposed || epoch != _sensorEpoch) return;
            if (v is List && v.length >= 2) {
              if (v.any((dynamic n) => n is! num || !n.isFinite)) return;
              motion.accept(
                (v[0] as num).toDouble(),
                (v[1] as num).toDouble(),
                v.length >= 5 ? (v[4] as num).toDouble() : 0,
                v.length >= 4 ? (v[2] as num).toDouble() : 0,
                v.length >= 4 ? (v[3] as num).toDouble() : 0,
              );
              sensorAvailable = motion.active;
            }
          },
          onError: (Object e) {
            sensorAvailable = false;
            motion.reset();
            physics.clearAcceleration();
            physics.gravity(0, 9.81);
          },
        );
  }

  @override
  void dispose() {
    _disposed = true;
    ++_sensorEpoch;
    unawaited(_sensor?.cancel());
    if (active == this) active = null;
    reservoirShader?.dispose();
    rgbShader?.dispose();
    super.dispose();
  }
}
