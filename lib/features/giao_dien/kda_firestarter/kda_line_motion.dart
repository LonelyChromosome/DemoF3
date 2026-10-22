import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Audio-event driven impulses. Render time only damps existing excitation;
/// it never creates a travelling carrier or generates new musical events.
class KdaLineMotion extends ChangeNotifier {
  double energy = 0;
  double bass = 0;
  double treble = 0;
  double density = 0;
  int inputCount = 0;
  int beatCount = 0;
  final List<KdaLinePulse> pulses = [];
  final List<double> _previous = List.filled(48, 0);
  final List<double> _targetRipple = List.filled(3, 0);
  final List<double> _ripple = List.filled(3, 0);
  final List<double> _eventTimes = [];
  double _clock = 0;
  double _age = 10;
  double? _lastSampleTime;
  double _lastEventTime = -10;
  double _bassFluxMean = 0;
  double _vocalFluxMean = 0;
  double _highFluxMean = 0;
  double _targetEnergy = 0;
  double _targetBass = 0;
  double _targetTreble = 0;
  bool _primed = false;

  bool get moving => pulses.isNotEmpty || _ripple.any((v) => v.abs() > .001) ||
      _targetRipple.any((v) => v.abs() > .001);

  void input(List<double> bands, {double? timestampSeconds}) {
    final sampleTime = timestampSeconds != null && timestampSeconds.isFinite
        ? timestampSeconds : _clock;
    _clock = math.max(_clock, sampleTime);
    final previousTime = _lastSampleTime;
    final dt = previousTime == null ? .05 : (sampleTime - previousTime).clamp(.02, .20);
    _lastSampleTime = sampleTime;
    final values = List<double>.generate(48, (i) => i < bands.length && bands[i].isFinite
        ? bands[i].clamp(0.0, 1.0) : 0.0, growable: false);
    double rms(int start, int end) {
      var sum = 0.0;
      for (var i = start; i < end; i++) { sum += values[i] * values[i]; }
      return math.sqrt(sum / (end - start));
    }
    double flux(int start, int end) {
      var sum = 0.0;
      for (var i = start; i < end; i++) { sum += math.max(0.0, values[i] - _previous[i]); }
      return sum / (end - start);
    }
    _targetEnergy = rms(0, 44);
    _targetBass = rms(0, 14);
    _targetTreble = rms(37, 48);
    final vocal = rms(14, 37);
    final bassFlux = flux(0, 14);
    final vocalFlux = flux(14, 37);
    final highFlux = flux(37, 48);
    final liveSignal = _targetEnergy > .055;
    inputCount++;
    _age = 0;
    if (_primed && liveSignal) {
      final bassThreshold = math.max(.025, _bassFluxMean * 1.45 + .008);
      final vocalThreshold = math.max(.018, _vocalFluxMean * 1.35 + .006);
      final highThreshold = math.max(.035, _highFluxMean * 1.5 + .010);
      final bassScore = bassFlux / bassThreshold;
      final vocalScore = vocalFlux / vocalThreshold;
      final highScore = highFlux / highThreshold;
      // Midrange spectral changes detect syllable-like attacks as well as
      // instruments. This does not claim vocal stem separation or a BPM grid.
      if (sampleTime - _lastEventTime >= .09 &&
          (bassScore > 1 || vocalScore > 1 || highScore > 1)) {
        final kind = bassScore >= vocalScore && bassScore >= highScore
            ? KdaPulseKind.bass : vocalScore >= highScore
            ? KdaPulseKind.vocal : KdaPulseKind.percussion;
        final novelty = kind == KdaPulseKind.bass ? bassFlux
            : kind == KdaPulseKind.vocal ? vocalFlux : highFlux;
        final level = kind == KdaPulseKind.bass ? _targetBass
            : kind == KdaPulseKind.vocal ? vocal : _targetTreble;
        final strength = (novelty * 2.0 + level * .35).clamp(.08, 1.0);
        pulses.add(KdaLinePulse(kind, strength, density));
        if (pulses.length > 6) pulses.removeAt(0);
        _lastEventTime = sampleTime;
        _eventTimes.add(sampleTime);
        beatCount++;
      }
      // Continuous small detail comes from measured frame-to-frame changes,
      // not a sine wave multiplied by loudness. Held tones settle in place.
      for (var group = 0; group < 3; group++) {
        final start = group == 0 ? 0 : group == 1 ? 14 : 37;
        final end = group == 0 ? 14 : group == 1 ? 37 : 48;
        var difference = 0.0;
        for (var i = start; i < end; i++) { difference += values[i] - _previous[i]; }
        _targetRipple[group] = (difference / (end - start) * 2.5).clamp(-.35, .35);
      }
    } else {
      _targetRipple.fillRange(0, 3, 0);
    }
    final adaptation = 1 - math.exp(-dt / .65);
    _bassFluxMean += (bassFlux - _bassFluxMean) * adaptation;
    _vocalFluxMean += (vocalFlux - _vocalFluxMean) * adaptation;
    _highFluxMean += (highFlux - _highFluxMean) * adaptation;
    _eventTimes.removeWhere((t) => sampleTime - t > 1);
    density = (_eventTimes.length / 6).clamp(0.0, 1.0);
    _previous.setAll(0, values);
    _primed = true;
  }

  void step(double elapsedSeconds) {
    final dt = elapsedSeconds.clamp(0.0, .10);
    _clock += dt;
    _age += dt;
    final live = _age < .25;
    final repaint = moving;
    double follow(double from, double target, double tau) =>
        from + (target - from) * (1 - math.exp(-dt / tau));
    energy = follow(energy, live && _targetEnergy > .055 ? _targetEnergy : 0, .08);
    bass = follow(bass, live ? _targetBass : 0, .06);
    treble = follow(treble, live ? _targetTreble : 0, .08);
    for (var i = 0; i < 3; i++) {
      _ripple[i] = follow(_ripple[i], live ? _targetRipple[i] : 0, .045);
      if (_ripple[i].abs() < .001) _ripple[i] = 0;
      if (!live) _targetRipple[i] = 0;
    }
    for (final p in pulses) { p.advance(dt); }
    pulses.removeWhere((p) => p.age >= p.duration);
    if (energy < .001) energy = 0;
    if (repaint || moving) notifyListeners();
  }

  double displacement(double u, double perimeter, double intensity) {
    var value = 0.0;
    final length = math.max(1.0, perimeter);
    for (var i = 0; i < 3; i++) {
      final center = const [.125, .625, .375][i];
      final d = (u - center + .5) % 1 - .5;
      final width = 65 / length;
      if (d.abs() < width) {
        value += _ripple[i] * (.5 + .5 * math.cos(math.pi * d / width));
      }
    }
    for (final p in pulses) {
      // Each actual attack launches a small packet that travels at most 12px,
      // then damps. No packet wraps around the perimeter or restarts itself.
      final travel = math.min(12.0, p.age * 65) / length;
      final width = p.width / length;
      for (final side in const [-1.0, 1.0]) {
        final center = (p.origin + side * travel) % 1;
        final d = (u - center + .5) % 1 - .5;
        if (d.abs() >= width) continue;
        final envelope = .5 + .5 * math.cos(math.pi * d / width);
        final shape = math.cos(math.pi * d / width * (p.kind == KdaPulseKind.vocal ? 1.35 : .65));
        value += envelope * shape * p.response * (side > 0 ? 1 : .65);
      }
    }
    return (value * intensity).clamp(-3.0, 3.0);
  }

  void reset() {
    energy = bass = treble = density = 0;
    _targetEnergy = _targetBass = _targetTreble = 0;
    _bassFluxMean = _vocalFluxMean = _highFluxMean = 0;
    _previous.fillRange(0, 48, 0);
    _targetRipple.fillRange(0, 3, 0);
    _ripple.fillRange(0, 3, 0);
    pulses.clear(); _eventTimes.clear();
    _age = 10; _clock = 0; _lastSampleTime = null;
    _lastEventTime = -10; _primed = false;
    inputCount = beatCount = 0;
    notifyListeners();
  }
}

enum KdaPulseKind { bass, vocal, percussion }

class KdaLinePulse {
  KdaLinePulse(this.kind, this.strength, double density)
      : duration = (kind == KdaPulseKind.bass ? .42 : .28) + density * .06,
        width = (kind == KdaPulseKind.bass ? 70.0 : 58.0) / (1 + density * .45);
  final KdaPulseKind kind;
  final double strength;
  final double duration;
  final double width;
  double age = 0;
  double response = 0;
  double get origin => kind == KdaPulseKind.bass ? .125
      : kind == KdaPulseKind.vocal ? .625 : .375;
  void advance(double dt) {
    age += dt;
    final tau = kind == KdaPulseKind.bass ? .12 : .085;
    final frequency = kind == KdaPulseKind.bass ? 4.0 : 3.0;
    final attack = (age / .018).clamp(0.0, 1.0);
    final force = kind == KdaPulseKind.bass ? 2.0 : 1.25;
    response = strength * force * attack * math.exp(-age / tau) * math.cos(age * math.pi * 2 * frequency);
  }
}
