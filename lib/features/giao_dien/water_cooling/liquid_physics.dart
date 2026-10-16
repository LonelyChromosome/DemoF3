import 'dart:math' as math;
import 'dart:typed_data';

/// 2D position-based fluid. Every sample carries the same mass; density
/// constraints couple neighbouring samples instead of rotating a surface.
/// Based on Macklin/Müller, Position Based Fluids (2013), adapted to 2D.
/// All solver arrays and spatial buckets are reused across frames.
class LiquidPhysics {
  static const capacity = 1500;
  final x = Float64List(capacity), y = Float64List(capacity);
  final vx = Float64List(capacity), vy = Float64List(capacity);
  final _oldX = Float64List(capacity), _oldY = Float64List(capacity);
  final _lambda = Float64List(capacity),
      _dx = Float64List(capacity),
      _dy = Float64List(capacity);
  final _head = Int32List(16384), _next = Int32List(capacity);
  final _density = Float64List(capacity);
  final _gradientX = Float64List(capacity), _gradientY = Float64List(capacity);
  final _gradientNorm = Float64List(capacity);
  // An unordered pair supplies both particles' pressure contribution. Its
  // distance/kernel is evaluated once per iteration rather than four times.
  var _pairI = Int32List(capacity * 16), _pairJ = Int32List(capacity * 16);
  var _pairX = Float64List(capacity * 16), _pairY = Float64List(capacity * 16);
  var _pairTensile = Float64List(capacity * 16);
  var _pairWeight = Float64List(capacity * 16);
  final _curl = Float64List(capacity);
  final _weight = Float64List(capacity);
  int _pairCount = 0;
  int count = 0, _cols = 1, _rows = 1;
  double aspect = .5, spacing = .015, support = .04, restDensity = 1;
  double gx = 0, gy = 9.81, gz = 0, _ax = 0, _ay = 0, _fill = -1;
  double coverage = .32;
  bool _lyingFlat = false;
  double _flatAge = 0;
  double get layerDepth => _fill / coverage;
  bool _reduced = false;
  double time = 0, kineticEnergy = 0, meanVx = 0, meanVy = 0;
  double get nx {
    final n = math.sqrt(gx * gx + gy * gy);
    return n > .1 ? gx / n : 0;
  }

  double get ny {
    final n = math.sqrt(gx * gx + gy * gy);
    return n > .1 ? gy / n : 1;
  }

  double get centerX {
    var s = 0.0;
    for (var i = 0; i < count; i++) {
      s += x[i];
    }
    return s / math.max(1, count);
  }

  double get centerY {
    var s = 0.0;
    for (var i = 0; i < count; i++) {
      s += y[i];
    }
    return s / math.max(1, count);
  }

  void gravity(double horizontal, double vertical, [double normal = 0]) {
    if (!horizontal.isFinite || !vertical.isFinite) return;
    gx = horizontal.clamp(-15, 15);
    gy = vertical.clamp(-15, 15);
    gz = normal.isFinite ? normal.clamp(-15, 15) : 0;
  }

  void acceleration(double horizontal, double vertical) {
    if (!horizontal.isFinite || !vertical.isFinite) return;
    _ax = horizontal.clamp(-55, 55);
    _ay = vertical.clamp(-55, 55);
  }

  void impulse(double amount) {
    for (var i = 0; i < count; i++) {
      final z = (x[i] / aspect - .5) * 2;
      vx[i] += amount * (.3 + .7 * (1 - y[i]));
      vy[i] -= amount * (.5 + .5 * math.sin(z * 3));
    }
  }

  void configure(double fill, double nextAspect, {bool reduced = false}) {
    nextAspect = nextAspect.clamp(.2, 3);
    if (count > 0 &&
        (_fill - fill).abs() < .001 &&
        _reduced == reduced &&
        (aspect - nextAspect).abs() < .01)
      return;
    final previous = aspect;
    final preserveCoverage =
        count > 0 && (_fill - fill).abs() < .001 && _reduced == reduced;
    aspect = nextAspect;
    if (count > 0 && (_fill - fill).abs() < .001 && _reduced == reduced) {
      for (var i = 0; i < count; i++) {
        x[i] *= aspect / previous;
        vx[i] *= aspect / previous;
      }
    } else {
      count = (fill * aspect / (reduced ? .00046 : .00025)).round().clamp(
        140,
        reduced ? 750 : capacity,
      );
      spacing = math.sqrt(fill * aspect / count);
      final columns = math.max(3, (aspect / spacing).floor());
      final stepX = aspect / columns;
      for (var i = 0; i < count; i++) {
        final row = i ~/ columns, col = i % columns;
        x[i] = (col + .5) * stepX;
        y[i] = 1 - (row + .5) * spacing;
        vx[i] = 0;
        vy[i] = 0;
      }
    }
    _fill = fill;
    _reduced = reduced;
    if (!preserveCoverage) {
      coverage = fill;
      _lyingFlat = false;
      _flatAge = 0;
    }
    spacing = math.sqrt(coverage * aspect / count);
    support = spacing * 2.8;
    _cols = (aspect / support).ceil() + 1;
    _rows = (1 / support).ceil() + 1;
    // The exact reference lattice uses the same compact kernel as density.
    restDensity = 0;
    for (var iy = -3; iy <= 3; iy++) {
      for (var ix = -3; ix <= 3; ix++) {
        final r = math.sqrt((ix * ix + iy * iy).toDouble()) / 2.8;
        if (r < 1) {
          final q = 1 - r;
          restDensity += q * q * q;
        }
      }
    }
  }

  void _hash() {
    _head.fillRange(0, _cols * _rows, -1);
    for (var i = 0; i < count; i++) {
      final cx = (x[i] / support).floor().clamp(0, _cols - 1);
      final cy = (y[i] / support).floor().clamp(0, _rows - 1);
      final key = cy * _cols + cx;
      _next[i] = _head[key];
      _head[key] = i;
    }
  }

  void _growPairs() {
    final size = _pairI.length * 2;
    _pairI = Int32List(size)..setRange(0, _pairCount, _pairI);
    _pairJ = Int32List(size)..setRange(0, _pairCount, _pairJ);
    _pairX = Float64List(size)..setRange(0, _pairCount, _pairX);
    _pairY = Float64List(size)..setRange(0, _pairCount, _pairY);
    _pairTensile = Float64List(size)..setRange(0, _pairCount, _pairTensile);
    _pairWeight = Float64List(size)..setRange(0, _pairCount, _pairWeight);
  }

  void _pressurePairs(double invRest, double invSupport) {
    _pairCount = 0;
    _density.fillRange(0, count, 1);
    _gradientX.fillRange(0, count, 0);
    _gradientY.fillRange(0, count, 0);
    _gradientNorm.fillRange(0, count, 0);
    final supportSquared = support * support;
    for (var i = 0; i < count; i++) {
      final cx = (x[i] / support).floor(), cy = (y[i] / support).floor();
      for (
        var yy = math.max(0, cy - 1);
        yy <= math.min(_rows - 1, cy + 1);
        yy++
      ) {
        for (
          var xx = math.max(0, cx - 1);
          xx <= math.min(_cols - 1, cx + 1);
          xx++
        ) {
          var j = _head[yy * _cols + xx];
          while (j >= 0) {
            if (j > i) {
              final dx = x[i] - x[j], dy = y[i] - y[j];
              final r2 = dx * dx + dy * dy;
              if (r2 < supportSquared && r2 > 1e-12) {
                final r = math.sqrt(r2), q = 1 - r * invSupport;
                final weight = q * q * q;
                final grad = -3 * q * q * invSupport * invRest / r;
                final a = dx * grad, b = dy * grad, norm = a * a + b * b;
                _density[i] += weight;
                _density[j] += weight;
                _gradientX[i] += a;
                _gradientX[j] -= a;
                _gradientY[i] += b;
                _gradientY[j] -= b;
                _gradientNorm[i] += norm;
                _gradientNorm[j] += norm;
                if (_pairCount == _pairI.length) _growPairs();
                _pairI[_pairCount] = i;
                _pairJ[_pairCount] = j;
                _pairX[_pairCount] = a;
                _pairY[_pairCount] = b;
                _pairTensile[_pairCount] = -supportSquared * .0007 * weight * q;
                _pairWeight[_pairCount] = weight;
                _pairCount++;
              }
            }
            j = _next[j];
          }
        }
      }
    }
  }

  void step(
    double dt, {
    required double fill,
    required double viscosity,
    required double aspect,
    bool reduced = false,
  }) {
    configure(fill, aspect, reduced: reduced);
    dt = dt.clamp(0, .04);
    if (dt == 0) return;
    time += dt;
    // A small volume forms a finite puddle on a flat acrylic plane. Normal
    // gravity changes depth/footprint, not mass. Hysteresis rejects sensor noise
    // near the flat threshold; accelerations cannot force a coverage jump.
    final norm = math.sqrt(gx * gx + gy * gy + gz * gz);
    final normalRatio = norm > 5 ? gz.abs() / norm : 0.0;
    if (normalRatio > .97 && _ax * _ax + _ay * _ay < 2.25) {
      _flatAge += dt;
      if (_flatAge >= .25) _lyingFlat = true;
    } else {
      _flatAge = 0;
      if (normalRatio < .90 || norm < 5) _lyingFlat = false;
    }
    final targetCoverage = _lyingFlat ? _flatCoverage(fill) : fill;
    coverage +=
        (targetCoverage - coverage) *
        (1 - math.exp(-dt * (_lyingFlat ? 1.5 : 2.6)));
    spacing = math.sqrt(coverage * aspect / count);
    support = spacing * 2.8;
    _cols = (aspect / support).ceil() + 1;
    _rows = (1 / support).ceil() + 1;
    final steps = math.max(1, (dt / (1 / 120)).ceil()), h = dt / steps;
    final invRest = 1 / restDensity, invSupport = 1 / support;
    for (var step = 0; step < steps; step++) {
      final contact = ((normalRatio - .90) * 10).clamp(0.0, 1.0);
      final damping = math.exp(-h * (.20 + viscosity * .4 + contact * 3));
      for (var i = 0; i < count; i++) {
        _oldX[i] = x[i];
        _oldY[i] = y[i];
        vx[i] = (vx[i] + (gx * .42 - _ax * .40) * h) * damping;
        vy[i] = (vy[i] + (gy * .42 - _ay * .40) * h) * damping;
        final speed = math.sqrt(vx[i] * vx[i] + vy[i] * vy[i]);
        if (speed > 3.5) {
          vx[i] *= 3.5 / speed;
          vy[i] *= 3.5 / speed;
        }
        x[i] += vx[i] * h;
        y[i] += vy[i] * h;
        _bounds(i);
      }
      for (var iter = 0; iter < (reduced ? 2 : 3); iter++) {
        _hash();
        _pressurePairs(invRest, invSupport);
        for (var i = 0; i < count; i++) {
          final constraint = math.max(0.0, _density[i] * invRest - 1);
          _lambda[i] =
              -constraint /
              (_gradientNorm[i] +
                  _gradientX[i] * _gradientX[i] +
                  _gradientY[i] * _gradientY[i] +
                  20);
        }
        _dx.fillRange(0, count, 0);
        _dy.fillRange(0, count, 0);
        for (var pair = 0; pair < _pairCount; pair++) {
          final i = _pairI[pair], j = _pairJ[pair];
          final change = _lambda[i] + _lambda[j] + _pairTensile[pair];
          final dx = _pairX[pair] * change, dy = _pairY[pair] * change;
          _dx[i] += dx;
          _dx[j] -= dx;
          _dy[i] += dy;
          _dy[j] -= dy;
        }
        for (var i = 0; i < count; i++) {
          final dx = _dx[i], dy = _dy[i];
          final distance = math.sqrt(dx * dx + dy * dy), limit = spacing * .35;
          final scale = distance > limit ? limit / distance : 1.0;
          _dx[i] = dx * scale;
          _dy[i] = dy * scale;
        }
        for (var i = 0; i < count; i++) {
          x[i] += _dx[i];
          y[i] += _dy[i];
          _bounds(i);
        }
      }
      for (var i = 0; i < count; i++) {
        vx[i] = (x[i] - _oldX[i]) / h;
        vy[i] = (y[i] - _oldY[i]) / h;
        final inset = spacing * .32;
        if ((x[i] <= inset + 1e-9 && vx[i] < 0) ||
            (x[i] >= aspect - inset - 1e-9 && vx[i] > 0))
          vx[i] *= -.06;
        if ((y[i] <= inset + 1e-9 && vy[i] < 0) ||
            (y[i] >= 1 - inset - 1e-9 && vy[i] > 0))
          vy[i] *= -.06;
      }
      _hash();
      _pressurePairs(invRest, invSupport);
      _dx.fillRange(0, count, 0);
      _dy.fillRange(0, count, 0);
      _curl.fillRange(0, count, 0);
      _weight.fillRange(0, count, 0);
      // Symmetric local exchange keeps viscosity independent of particle order.
      for (var pair = 0; pair < _pairCount; pair++) {
        final i = _pairI[pair], j = _pairJ[pair];
        final w = _pairWeight[pair];
        final du = vx[j] - vx[i], dv = vy[j] - vy[i];
        _dx[i] += du * w;
        _dx[j] -= du * w;
        _dy[i] += dv * w;
        _dy[j] -= dv * w;
        _weight[i] += w;
        _weight[j] += w;
        final curl = du * _pairY[pair] - dv * _pairX[pair];
        _curl[i] += curl;
        _curl[j] += curl;
      }
      var energyBefore = 0.0, energyAfter = 0.0;
      for (var i = 0; i < count; i++) {
        energyBefore += vx[i] * vx[i] + vy[i] * vy[i];
        final amount =
            (.008 + viscosity * .065) * (h * 120) / math.max(1.0, _weight[i]);
        vx[i] += _dx[i] * amount;
        vy[i] += _dy[i] * amount;
        energyAfter += vx[i] * vx[i] + vy[i] * vy[i];
      }
      // Surface cohesion is local, paired and weak. It prevents flat water from
      // dispersing into screen-wide mist without pulling it toward a fake shape.
      for (var pair = 0; pair < _pairCount; pair++) {
        final i = _pairI[pair], j = _pairJ[pair];
        final amount = support * h * (.12 + contact * .65);
        final a = _pairX[pair] * amount, b = _pairY[pair] * amount;
        vx[i] += a;
        vx[j] -= a;
        vy[i] += b;
        vy[j] -= b;
      }
      // Preserve curls lost to viscosity, with a strict dissipated-energy budget.
      // No force from time/noise: still water must eventually become still.
      _gradientX.fillRange(0, count, 0);
      _gradientY.fillRange(0, count, 0);
      for (var pair = 0; pair < _pairCount; pair++) {
        final i = _pairI[pair], j = _pairJ[pair];
        final change = _curl[j].abs() - _curl[i].abs();
        _gradientX[i] += change * _pairX[pair];
        _gradientX[j] += change * _pairX[pair];
        _gradientY[i] += change * _pairY[pair];
        _gradientY[j] += change * _pairY[pair];
      }
      final energy = energyAfter / math.max(1, count);
      final strength = support * .08 * energy / (.02 + energy);
      var cross = 0.0, squared = 0.0;
      for (var i = 0; i < count; i++) {
        final a = _gradientX[i], b = _gradientY[i];
        final length = math.sqrt(a * a + b * b);
        final force = length > 1e-9
            ? strength * _curl[i].clamp(-100, 100) * h / length
            : 0.0;
        _dx[i] = b * force;
        _dy[i] = -a * force;
        cross += vx[i] * _dx[i] + vy[i] * _dy[i];
        squared += _dx[i] * _dx[i] + _dy[i] * _dy[i];
      }
      final budget = math.max(0.0, energyBefore - energyAfter) * .35;
      final gain = squared > 1e-15
          ? ((-cross + math.sqrt(cross * cross + squared * budget)) / squared)
                .clamp(0.0, 1.0)
          : 0.0;
      for (var i = 0; i < count; i++) {
        vx[i] += _dx[i] * gain;
        vy[i] += _dy[i] * gain;
      }
      _ax *= math.exp(-h * 9);
      _ay *= math.exp(-h * 9);
    }
    var energy = 0.0, a = 0.0, b = 0.0;
    for (var i = 0; i < count; i++) {
      energy += vx[i] * vx[i] + vy[i] * vy[i];
      a += vx[i];
      b += vy[i];
    }
    kineticEnergy = energy / math.max(1, count);
    meanVx = a / math.max(1, count);
    meanVy = b / math.max(1, count);
  }

  double _flatCoverage(double fill) =>
      math.max(fill, math.min(.96, 1.3 * math.pow(fill, 2 / 3)));

  void clearAcceleration() {
    _ax = _ay = 0;
  }

  /// Rehydrate hydrostatic water once after suspension, using fresh gravity.
  /// Never integrate elapsed background time or replay old shake impulses.
  void settleAfterSuspension() {
    clearAcceleration();
    if (count == 0) return;
    final norm = math.sqrt(gx * gx + gy * gy + gz * gz);
    _lyingFlat = norm > 5 && gz.abs() / norm > .97;
    _flatAge = _lyingFlat ? .25 : 0;
    coverage = _lyingFlat ? _flatCoverage(_fill) : _fill;
    spacing = math.sqrt(coverage * aspect / count);
    support = spacing * 2.8;
    final columns = math.max(3, (aspect / spacing).round());
    final rows = math.max(
      (count / columns).ceil(),
      math.max(3, (1 / spacing).round()),
    );
    // Temporary ordering only on resume, never in the render loop.
    final cells = List<int>.generate(columns * rows, (i) => i);
    double potential(int index) {
      final px = (index % columns + .5) / columns;
      final py = (index ~/ columns + .5) / rows;
      return _lyingFlat
          ? -math.pow((px - .5) * aspect, 2).toDouble() - math.pow(py - .5, 2)
          : gx * px * aspect + gy * py;
    }

    cells.sort((a, b) => potential(b).compareTo(potential(a)));
    for (var i = 0; i < count; i++) {
      x[i] = (cells[i] % columns + .5) * aspect / columns;
      y[i] = (cells[i] ~/ columns + .5) / rows;
      vx[i] = vy[i] = 0;
      _bounds(i);
    }
    kineticEnergy = meanVx = meanVy = 0;
  }

  void _bounds(int i) {
    // Slip boundary: no adhesion to the screen or wall. The pressure solve
    // transfers impacts back into neighbouring water rather than deleting mass.
    final inset = spacing * .32;
    x[i] = x[i].clamp(inset, aspect - inset);
    y[i] = y[i].clamp(inset, 1 - inset);
  }
}
