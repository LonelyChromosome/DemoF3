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

  bool get moving => pulses.isNotEmpty;

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
      for (var i = start; i < end; i++) {
        final rise = math.max(0.0, values[i] - _previous[i]);
        sum += rise * rise;
      }
      return math.sqrt(sum / (end - start));
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
        // The preceding real onset controls travel time, not a free-running
        // beat clock. A single event owns both incoming wave fronts.
        final interval = _lastEventTime < 0 ? .45 : sampleTime - _lastEventTime;
        pulses.add(KdaLinePulse(kind, strength, interval));
        if (pulses.length > 6) pulses.removeAt(0);
        _lastEventTime = sampleTime;
        _eventTimes.add(sampleTime);
        beatCount++;
      }
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
    // Analytic damping can use real elapsed time, including a delayed frame.
    final dt = elapsedSeconds.isFinite ? elapsedSeconds.clamp(0.0, 2.0) : 0.0;
    _clock += dt;
    _age += dt;
    final live = _age < .25;
    final repaint = moving;
    double follow(double from, double target, double tau) =>
        from + (target - from) * (1 - math.exp(-dt / tau));
    energy = follow(energy, live && _targetEnergy > .055 ? _targetEnergy : 0, .08);
    bass = follow(bass, live ? _targetBass : 0, .06);
    treble = follow(treble, live ? _targetTreble : 0, .08);
    for (final p in pulses) { p.advance(dt); }
    pulses.removeWhere((p) => p.age >= p.duration);
    if (energy < .001) energy = 0;
    if (repaint || moving) notifyListeners();
  }

  /// [x] is physical left-to-right position across the card, not path phase.
  /// The painter uses identical x on top/bottom, preserving both symmetries
  /// regardless of the rounded rectangle's path origin or aspect ratio.
  double displacement(double x, double cardWidth, double intensity) {
    var value = 0.0;
    final width = math.max(1.0, cardWidth);
    for (final p in pulses) {
      final packetWidth = (p.width / width).clamp(.08, .24);
      var pair = 0.0;
      for (final center in [p.front, 1 - p.front]) {
        final d = (x - center) / packetWidth;
        if (d.abs() >= 1) continue;
        final envelope = .5 + .5 * math.cos(math.pi * d);
        pair += envelope * math.cos(math.pi * d * 1.5);
      }
      // Merge the two fronts without doubling amplitude as they meet.
      value += pair.clamp(-1.0, 1.0) * p.response;
    }
    return (value * intensity).clamp(-2.0, 2.0);
  }

  void reset() {
    energy = bass = treble = density = 0;
    _targetEnergy = _targetBass = _targetTreble = 0;
    _bassFluxMean = _vocalFluxMean = _highFluxMean = 0;
    _previous.fillRange(0, 48, 0);
    pulses.clear(); _eventTimes.clear();
    _age = 10; _clock = 0; _lastSampleTime = null;
    _lastEventTime = -10; _primed = false;
    inputCount = beatCount = 0;
    notifyListeners();
  }
}

enum KdaPulseKind { bass, vocal, percussion }

class KdaLinePulse {
  KdaLinePulse(this.kind, this.strength, double interval)
      : duration = (interval * .85).clamp(.24, .56),
        width = kind == KdaPulseKind.bass ? 74 : 58;
  final KdaPulseKind kind;
  final double strength;
  final double duration;
  final double width;
  double age = 0;
  double response = 0;
  // Travel once, from both sides to the centre; never wrap or bounce back.
  double get progress => (age / duration).clamp(0.0, 1.0);
  double get front => .04 + .46 * (progress / .8).clamp(0.0, 1.0);
  void advance(double dt) {
    age += dt;
    final attack = (age / .018).clamp(0.0, 1.0);
    final fade = ((1 - progress) / .26).clamp(0.0, 1.0);
    final force = kind == KdaPulseKind.bass ? 2.2 : 1.8;
    response = strength * force * attack * fade;
  }
}
