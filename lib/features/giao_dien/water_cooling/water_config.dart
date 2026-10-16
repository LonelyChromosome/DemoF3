import 'package:flutter/material.dart';

import '../du_lieu/widget_theme_configuration.dart';
import '../phong_chu/font_choice.dart';

enum LedMode {
  static,
  rainbow,
  wave,
  beam,
  fire,
  breathing,
  pulse,
  meteor,
  gradient,
  custom,
  rainbowLine,
}

@immutable
class WaterConfig {
  const WaterConfig({
    this.mode = LedMode.wave,
    this.colors = const [
      Color(0xFFAC70FF),
      Color(0xFFFF4DAD),
      Color(0xFFEE315E),
    ],
    this.speed = .35,
    this.brightness = .7,
    this.glow = .22,
    this.direction = 0,
    this.waveWidth = .65,
    this.beamWidth = .16,
    this.intensity = .65,
    this.fill = .32,
    this.viscosity = .22,
    this.coolant = const Color(0xFF7341AA),
    this.bubbles = .25,
    this.refraction = .45,
    this.tubeWidth = 1.6,
    this.metal = .55,
    this.border = true,
    this.tilt = true,
    this.reduced = false,
    this.widgets = const WidgetThemeConfiguration(),
    this.font = AppFontChoice.system,
  });
  final LedMode mode;
  final List<Color> colors;
  final double speed,
      brightness,
      glow,
      direction,
      waveWidth,
      beamWidth,
      intensity,
      fill,
      viscosity,
      bubbles,
      refraction,
      tubeWidth,
      metal;
  final Color coolant;
  final bool border, tilt, reduced;
  final WidgetThemeConfiguration widgets;
  final AppFontChoice font;
  factory WaterConfig.fromJson(Map<String, dynamic> j) {
    double n(String k, double d, [double lo = 0, double hi = 1]) {
      final v = j[k];
      return v is num && v.toDouble().isFinite ? v.toDouble().clamp(lo, hi) : d;
    }

    var colors =
        (j['colors'] as List?)
            ?.whereType<num>()
            .take(4)
            .map((v) => Color(v.toInt()))
            .toList() ??
        <Color>[];
    if (j['schema'] == 1 &&
        colors.map((c) => c.toARGB32()).join(',') ==
            '4282967505,4284910847,4291132671')
      colors = const WaterConfig().colors;
    return WaterConfig(
      mode: LedMode.values.firstWhere(
        (m) => m.name == j['mode'],
        orElse: () => LedMode.wave,
      ),
      colors: colors.isEmpty
          ? const WaterConfig().colors
          : List.unmodifiable(colors),
      speed: n('speed', .35),
      brightness: n('brightness', .7),
      glow: n('glow', .22),
      direction: n('direction', 0, 0, 360),
      waveWidth: n('waveWidth', .65, .08, 2),
      beamWidth: n('beamWidth', .16, .02, 1),
      intensity: n('intensity', .65),
      fill: j['schema'] == 1
          ? (n('fill', .64, .15, .9) * .5).clamp(.08, .9)
          : n('fill', .32, .08, .9),
      viscosity: j['schema'] == 1 && j['viscosity'] == .5
          ? .22
          : n('viscosity', .22),
      coolant: Color(
        j['schema'] == 1 && j['coolant'] == 0xFF196D76
            ? 0xFF7341AA
            : (j['coolant'] as num?)?.toInt() ?? 0xFF7341AA,
      ),
      bubbles: n('bubbles', .25),
      refraction: n('refraction', .45),
      tubeWidth: j['schema'] == 1 && j['tubeWidth'] == 2.4
          ? 1.6
          : n('tubeWidth', 1.6, .8, 6),
      metal: n('metal', .55),
      border: j['border'] != false,
      tilt: j['tilt'] != false,
      reduced: j['reduced'] == true,
      widgets: j['widgets'] is Map
          ? WidgetThemeConfiguration.fromJson(
              Map<String, Object?>.from(j['widgets'] as Map),
            )
          : const WidgetThemeConfiguration(),
      font: AppFontChoice.builtIns.firstWhere(
        (f) => f.id == j['fontId'],
        orElse: () => AppFontChoice.system,
      ),
    );
  }
  Map<String, Object?> toJson() => {
    'schema': 2,
    'mode': mode.name,
    'colors': colors.map((c) => c.toARGB32()).toList(),
    'speed': speed,
    'brightness': brightness,
    'glow': glow,
    'direction': direction,
    'waveWidth': waveWidth,
    'beamWidth': beamWidth,
    'intensity': intensity,
    'fill': fill,
    'viscosity': viscosity,
    'coolant': coolant.toARGB32(),
    'bubbles': bubbles,
    'refraction': refraction,
    'tubeWidth': tubeWidth,
    'metal': metal,
    'border': border,
    'tilt': tilt,
    'reduced': reduced,
    'widgets': widgets.toJson(),
    'fontId': font.id,
  };
  WaterConfig patch(Map<String, Object?> values) =>
      WaterConfig.fromJson({...toJson(), ...values});
}
