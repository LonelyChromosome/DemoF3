import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'liquid_physics.dart';

/// Reconstructs one continuous fluid boundary from density. Samples themselves
/// are never painted as dots. Marching-square edges are joined into closed
/// contours, including disconnected droplets and air cavities.
class LiquidSurface {
  final path = ui.Path()..fillType = ui.PathFillType.evenOdd;
  final _primary = ui.Path()..fillType = ui.PathFillType.evenOdd;
  final _preview = ui.Path()..fillType = ui.PathFillType.evenOdd;
  final field = Float64List(24000);
  final _cellMeans = Float64List(24000), _cellAreas = Float64List(24000);
  final _histogram = Float64List(2048);
  final _a = Int32List(48000), _b = Int32List(48000), _seen = Int32List(48000);
  final _edgeX = Float64List(48000), _edgeY = Float64List(48000);
  final _px = Float64List(48000), _py = Float64List(48000);
  final _matrix = Float64List(16)
    ..[10] = 1
    ..[15] = 1;
  int cols = 0, rows = 0, contours = 0, _epoch = 0;
  double cell = 1 / 120, area = 0, iso = .65;
  void rebuild(
    LiquidPhysics fluid, {
    Float64List? positionX,
    Float64List? positionY,
  }) {
    final xPositions = positionX ?? fluid.x, yPositions = positionY ?? fluid.y;
    cell = math.max(1 / 120, math.sqrt(fluid.aspect / 18000));
    cols = (fluid.aspect / cell).ceil() + 3;
    rows = (1 / cell).ceil() + 3;
    final points = cols * rows;
    field.fillRange(0, points, 0);
    final radius = fluid.support * 1.05, r2 = radius * radius;
    for (var i = 0; i < fluid.count; i++) {
      final px = xPositions[i], py = yPositions[i];
      final x0 = math.max(1, ((px - radius) / cell + 1).floor()),
          x1 = math.min(cols - 2, ((px + radius) / cell + 1).ceil());
      final y0 = math.max(1, ((py - radius) / cell + 1).floor()),
          y1 = math.min(rows - 2, ((py + radius) / cell + 1).ceil());
      for (var y = y0; y <= y1; y++) {
        final dy = (y - 1) * cell - py;
        for (var x = x0; x <= x1; x++) {
          final dx = (x - 1) * cell - px, d2 = dx * dx + dy * dy;
          if (d2 < r2) {
            final q = 1 - math.sqrt(d2) / radius;
            field[y * cols + x] += q * q * q;
          }
        }
      }
    }
    _a.fillRange(0, points * 2, -1);
    _b.fillRange(0, points * 2, -1);
    // Preserve projected water volume when splashes separate. A fixed kernel
    // threshold otherwise inflates disconnected drops as their kernels stop
    // overlapping. This density threshold changes shape, never a plane angle.
    final target = fluid.coverage * fluid.aspect;
    // One weighted histogram replaces eight full-grid bisection scans. Its
    // bins are finer than the previous threshold precision; grid resolution,
    // particle count, water volume and disconnected contours stay unchanged.
    const low = .015;
    final binScale = _histogram.length / (fluid.restDensity - low);
    _histogram.fillRange(0, _histogram.length, 0);
    for (var y = 0; y < rows - 1; y++) {
      final height = y == 0
          ? 0.0
          : math.min(cell, math.max(0.0, 1 - (y - 1) * cell));
      for (var x = 0; x < cols - 1; x++) {
        final i = y * cols + x;
        final mean =
            (field[i] + field[i + 1] + field[i + cols] + field[i + cols + 1]) *
            .25;
        final weight = x == 0
            ? 0.0
            : height *
                  math.min(cell, math.max(0.0, fluid.aspect - (x - 1) * cell));
        _cellMeans[i] = mean;
        _cellAreas[i] = weight;
        if (mean >= low && weight > 0) {
          final bin = ((mean - low) * binScale).floor().clamp(
            0,
            _histogram.length - 1,
          );
          _histogram[bin] += weight;
        }
      }
    }
    var occupied = 0.0;
    iso = low;
    for (var bin = _histogram.length - 1; bin >= 0; bin--) {
      final weight = _histogram[bin];
      if (weight > 0 && occupied + weight >= target) {
        final fraction = ((target - occupied) / weight).clamp(0.0, 1.0);
        iso = low + (bin + 1 - fraction) / binScale;
        break;
      }
      occupied += weight;
    }
    area = 0;
    for (var y = 0; y < rows - 1; y++) {
      for (var x = 0; x < cols - 1; x++) {
        final i = y * cols + x;
        final f0 = field[i],
            f1 = field[i + 1],
            f2 = field[i + cols + 1],
            f3 = field[i + cols];
        final mask =
            (f0 >= iso ? 1 : 0) |
            (f1 >= iso ? 2 : 0) |
            (f2 >= iso ? 4 : 0) |
            (f3 >= iso ? 8 : 0);
        if (_cellMeans[i] >= iso) area += _cellAreas[i];
        if (mask == 0 || mask == 15) continue;
        final top = i * 2,
            right = (i + 1) * 2 + 1,
            bottom = (i + cols) * 2,
            left = i * 2 + 1;
        if ((mask & 1) != (mask & 2) >> 1)
          _edge(top, x.toDouble(), y.toDouble(), x + 1.0, y.toDouble(), f0, f1);
        if (((mask >> 1) & 1) != ((mask >> 2) & 1))
          _edge(right, x + 1.0, y.toDouble(), x + 1.0, y + 1.0, f1, f2);
        if (((mask >> 2) & 1) != ((mask >> 3) & 1))
          _edge(bottom, x.toDouble(), y + 1.0, x + 1.0, y + 1.0, f3, f2);
        if ((mask & 1) != ((mask >> 3) & 1))
          _edge(
            left,
            x.toDouble(),
            y.toDouble(),
            x.toDouble(),
            y + 1.0,
            f0,
            f3,
          );
        switch (mask) {
          case 1:
          case 14:
            _connect(left, top);
          case 2:
          case 13:
            _connect(top, right);
          case 3:
          case 12:
            _connect(left, right);
          case 4:
          case 11:
            _connect(right, bottom);
          case 6:
          case 9:
            _connect(top, bottom);
          case 7:
          case 8:
            _connect(left, bottom);
          case 5:
            if (f0 + f1 + f2 + f3 > iso * 4) {
              _connect(top, right);
              _connect(bottom, left);
            } else {
              _connect(left, top);
              _connect(right, bottom);
            }
          case 10:
            if (f0 + f1 + f2 + f3 > iso * 4) {
              _connect(left, top);
              _connect(right, bottom);
            } else {
              _connect(top, right);
              _connect(bottom, left);
            }
        }
      }
    }
    path.reset();
    path.fillType = ui.PathFillType.evenOdd;
    contours = 0;
    _epoch++;
    for (var id = 0; id < points * 2; id++) {
      if (_a[id] < 0 || _seen[id] == _epoch) continue;
      var current = id, previous = -1, n = 0;
      do {
        _seen[current] = _epoch;
        _px[n] = _edgeX[current];
        _py[n] = _edgeY[current];
        n++;
        final next = _a[current] != previous ? _a[current] : _b[current];
        previous = current;
        current = next;
      } while (current >= 0 &&
          current != id &&
          _seen[current] != _epoch &&
          n < points * 2);
      if (n < 3) continue;
      path.moveTo((_px[n - 1] + _px[0]) * .5, (_py[n - 1] + _py[0]) * .5);
      for (var i = 0; i < n; i++) {
        final next = (i + 1) % n;
        path.quadraticBezierTo(
          _px[i],
          _py[i],
          (_px[i] + _px[next]) * .5,
          (_py[i] + _py[next]) * .5,
        );
      }
      path.close();
      contours++;
    }
  }

  void _edge(
    int id,
    double ax,
    double ay,
    double bx,
    double by,
    double fa,
    double fb,
  ) {
    final t = ((iso - fa) / (fb - fa)).clamp(0.0, 1.0);
    _edgeX[id] = (ax + (bx - ax) * t - 1) * cell;
    _edgeY[id] = (ay + (by - ay) * t - 1) * cell;
  }

  void _connect(int x, int y) {
    if (_a[x] < 0) {
      _a[x] = y;
    } else {
      _b[x] = y;
    }
    if (_a[y] < 0) {
      _a[y] = x;
    } else {
      _b[y] = x;
    }
  }

  ui.Path scaled(ui.Size size, double aspect, {bool preview = false}) {
    final result = preview ? _preview : _primary;
    _matrix[0] = size.width / aspect;
    _matrix[5] = size.height;
    result.reset();
    result.fillType = ui.PathFillType.evenOdd;
    result.addPath(path, ui.Offset.zero, matrix4: _matrix);
    return result;
  }
}
