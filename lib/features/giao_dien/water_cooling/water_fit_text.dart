import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// Measures the selected font with the actual text scaler and allocated width.
/// The title region is capped; metadata and action hitboxes keep their space.
class WaterFitText extends StatelessWidget {
  const WaterFitText(
    this.text, {
    this.style,
    this.maxLines = 2,
    this.overflow,
    this.minSize = 10,
    this.maxSize = 14,
    this.heightLimit = 42,
    super.key,
  });
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final double minSize, maxSize, heightLimit;
  static Widget whenWater(
    String text, {
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
  }) => appThemePalette.id == AppThemeId.waterCooling
      ? WaterFitText(
          text,
          style: style,
          maxLines: maxLines ?? 2,
          maxSize: (style?.fontSize ?? 14).clamp(10, 14),
          heightLimit: (maxLines ?? 2) == 1 ? 22 : 42,
        )
      : Text(text, style: style, maxLines: maxLines, overflow: overflow);
  static Widget date(String text, {required TextStyle style}) {
    final label = Text(
      text,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: style,
    );
    return appThemePalette.id == AppThemeId.waterCooling
        ? FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, maxLines: 1, softWrap: false, style: style),
          )
        : label;
  }

  static Widget time(String text, {required TextStyle style}) {
    final label = Text(text, style: style);
    return appThemePalette.id == AppThemeId.waterCooling
        ? SizedBox(
            width: 58,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: label,
            ),
          )
        : label;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final inherited = DefaultTextStyle.of(context).style.merge(style),
          scaler = MediaQuery.textScalerOf(context),
          direction = Directionality.of(context),
          allowedLines = maxLines ?? 2;
      final width = c.maxWidth.isFinite ? c.maxWidth : 1000.0,
          height = c.maxHeight.isFinite
              ? c.maxHeight.clamp(0.0, heightLimit)
              : heightLimit;
      var lo = minSize, hi = maxSize;
      var lines = allowedLines;
      final probe = TextPainter(
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
        text: TextSpan(
          text: text,
          style: inherited.copyWith(fontSize: minSize, height: 1.2),
        ),
      )..layout(maxWidth: width);
      if (!probe.didExceedMaxLines && probe.height <= height) lines = 1;
      probe.dispose();
      final p = TextPainter(
        textDirection: direction,
        textScaler: scaler,
        maxLines: lines,
      );
      for (var i = 0; i < 12; i++) {
        final size = (lo + hi) / 2;
        p.text = TextSpan(
          text: text,
          style: inherited.copyWith(fontSize: size, height: 1.14),
        );
        p.layout(maxWidth: width);
        if (p.didExceedMaxLines || p.height > height) {
          hi = size;
        } else {
          lo = size;
        }
      }
      p.dispose();
      return Text(
        text,
        style: inherited.copyWith(fontSize: lo, height: 1.14),
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}
