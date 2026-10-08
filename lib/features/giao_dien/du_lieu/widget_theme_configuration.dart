import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum WidgetSurfaceKind { small, large, widget2 }

@immutable
final class WidgetBorderDefinition {
  const new({
    this.enabled = false,
    this.color = const Color(0xFFFFD66B),
    this.width = 1,
    this.tienMonStyle = false,
  });

  factory WidgetBorderDefinition.fromJson(Map<String, Object?> json) =>
      WidgetBorderDefinition(
        enabled: json['enabled'] as bool? ?? false,
        color: Color((json['color'] as num?)?.toInt() ?? 0xFFFFD66B),
        width: ((json['widthDp'] as num?)?.toDouble() ?? 1).clamp(.5, 8),
        tienMonStyle: json['tienMonStyle'] as bool? ?? false,
      );

  final bool enabled;
  final Color color;
  final double width;
  final bool tienMonStyle;

  WidgetBorderDefinition copyWith({
    bool? enabled,
    Color? color,
    double? width,
    bool? tienMonStyle,
  }) => WidgetBorderDefinition(
    enabled: enabled ?? this.enabled,
    color: color ?? this.color,
    width: width ?? this.width,
    tienMonStyle: tienMonStyle ?? this.tienMonStyle,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'color': color.toARGB32(),
    'widthDp': width,
    'tienMonStyle': tienMonStyle,
  };
}

@immutable
final class WidgetThemeConfiguration {
  const new({
    this.largeImagePath = '',
    this.widget2ImagePath = '',
    this.smallBorder = const WidgetBorderDefinition(),
    this.largeBorder = const WidgetBorderDefinition(),
    this.widget2Border = const WidgetBorderDefinition(),
    this.cornerRadius = 18,
    this.glassOpacity = .58,
    this.glowStrength = .32,
  });

  factory WidgetThemeConfiguration.fromJson(Map<String, Object?> json) {
    WidgetBorderDefinition border(String key) {
      final value = json[key];
      if (value is! Map<Object?, Object?>) {
        return const WidgetBorderDefinition();
      }
      return WidgetBorderDefinition.fromJson(Map<String, Object?>.from(value));
    }

    return WidgetThemeConfiguration(
      largeImagePath: json['largeImagePath'] as String? ?? '',
      widget2ImagePath: json['widget2ImagePath'] as String? ?? '',
      smallBorder: border('smallBorder'),
      largeBorder: border('largeBorder'),
      widget2Border: border('widget2Border'),
      cornerRadius: ((json['cornerRadiusDp'] as num?)?.toDouble() ?? 18).clamp(
        0,
        28,
      ),
      glassOpacity: ((json['glassOpacity'] as num?)?.toDouble() ?? .58).clamp(
        .18,
        .92,
      ),
      glowStrength: ((json['glowStrength'] as num?)?.toDouble() ?? .32).clamp(
        0,
        1,
      ),
    );
  }

  final String largeImagePath;
  final String widget2ImagePath;
  final WidgetBorderDefinition smallBorder;
  final WidgetBorderDefinition largeBorder;
  final WidgetBorderDefinition widget2Border;
  final double cornerRadius;
  final double glassOpacity;
  final double glowStrength;

  WidgetBorderDefinition borderFor(WidgetSurfaceKind kind) => switch (kind) {
    WidgetSurfaceKind.small => smallBorder,
    WidgetSurfaceKind.large => largeBorder,
    WidgetSurfaceKind.widget2 => widget2Border,
  };

  WidgetThemeConfiguration withBorder(
    WidgetSurfaceKind kind,
    WidgetBorderDefinition border,
  ) => switch (kind) {
    WidgetSurfaceKind.small => copyWith(smallBorder: border),
    WidgetSurfaceKind.large => copyWith(largeBorder: border),
    WidgetSurfaceKind.widget2 => copyWith(widget2Border: border),
  };

  WidgetThemeConfiguration copyWith({
    String? largeImagePath,
    String? widget2ImagePath,
    WidgetBorderDefinition? smallBorder,
    WidgetBorderDefinition? largeBorder,
    WidgetBorderDefinition? widget2Border,
    double? cornerRadius,
    double? glassOpacity,
    double? glowStrength,
  }) => WidgetThemeConfiguration(
    largeImagePath: largeImagePath ?? this.largeImagePath,
    widget2ImagePath: widget2ImagePath ?? this.widget2ImagePath,
    smallBorder: smallBorder ?? this.smallBorder,
    largeBorder: largeBorder ?? this.largeBorder,
    widget2Border: widget2Border ?? this.widget2Border,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    glassOpacity: glassOpacity ?? this.glassOpacity,
    glowStrength: glowStrength ?? this.glowStrength,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': 1,
    'largeImagePath': largeImagePath,
    'widget2ImagePath': widget2ImagePath,
    'smallBorder': smallBorder.toJson(),
    'largeBorder': largeBorder.toJson(),
    'widget2Border': widget2Border.toJson(),
    'cornerRadiusDp': cornerRadius,
    'glassOpacity': glassOpacity,
    'glowStrength': glowStrength,
  };
}
