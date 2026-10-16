import 'dart:math' as m;

import 'package:flutter/material.dart';

import 'water_config.dart';

abstract final class MasterRgbField {
  static Color sample(WaterConfig c, double x, double y, double seconds) {
    final angle = c.direction * m.pi / 180,
        p = (x - .5) * m.cos(angle) + (y - .5) * m.sin(angle) + .5,
        t = seconds * (.04 + c.speed * .7);
    double fract(double v) => v - v.floorToDouble();
    Color palette(double u) {
      final v = fract(u) * c.colors.length;
      return Color.lerp(
        c.colors[v.floor() % c.colors.length],
        c.colors[(v.floor() + 1) % c.colors.length],
        v % 1,
      )!;
    }

    var color = c.colors.first;
    var light = 1.0;
    switch (c.mode) {
      case LedMode.static:
        break;
      case LedMode.rainbow:
        color = HSVColor.fromAHSV(1, fract(p - t) * 360, .8, 1).toColor();
      case LedMode.wave:
        color = palette(p / c.waveWidth - t);
      case LedMode.beam:
        light = .06 + .94 * m.exp(-m.pow((fract(p - t) - .5) / c.beamWidth, 2));
      case LedMode.meteor:
        light = .06 + .94 * m.exp(-fract(p - t) / c.beamWidth);
      case LedMode.fire:
        final f =
            (.5 +
                    .25 * m.sin(x * 8 + t * 7) +
                    .25 * m.sin(y * 13 - t * 11 + x * 4))
                .clamp(0.0, 1.0);
        color = Color.lerp(
          const Color(0xFFB91E09),
          const Color(0xFFFFC85B),
          f,
        )!;
        light = .35 + .65 * f;
      case LedMode.breathing:
        light = .18 + .82 * (.5 + .5 * m.sin(t * m.pi * 2));
      case LedMode.pulse:
        light =
            .08 + .92 * m.pow((.5 + .5 * m.cos(t * m.pi * 2)).clamp(0, 1), 9);
      case LedMode.gradient:
        color = palette(p * .65);
      case LedMode.custom:
        color = palette(p - t);
      case LedMode.rainbowLine:
        color = HSVColor.fromAHSV(
          1,
          fract(
                x * (3 * m.cos(angle) + 2 * m.sin(angle)) +
                    y * (-3 * m.sin(angle) + 2 * m.cos(angle)) -
                    t,
              ) *
              360,
          .8,
          1,
        ).toColor();
    }
    final gain = c.brightness * (1 - c.intensity + c.intensity * light);
    return Color.from(
      alpha: 1,
      red: color.r * gain,
      green: color.g * gain,
      blue: color.b * gain,
    );
  }
}
