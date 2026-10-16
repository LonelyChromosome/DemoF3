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
    this.maxSize,
    this.heightLimit = 42,
    super.key,
  });
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final double minSize, heightLimit;
  final double? maxSize;
  static Widget whenWater(
    String text, {
    TextStyle? style,
    int? maxLines,
    TextOverflow? overflow,
    double minSize = 10,
    double? heightLimit,
  }) => appThemePalette.id == AppThemeId.waterCooling
      ? WaterFitText(
          text,
          style: style,
          maxLines: maxLines ?? 2,
          maxSize: style?.fontSize,
          overflow: overflow,
          minSize: minSize,
          heightLimit: heightLimit ?? ((maxLines ?? 2) == 1 ? 22 : 42),
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
      final nominal = maxSize ?? inherited.fontSize ?? 14;
      final minimum = minSize.clamp(0.0, nominal);
      var chosen = minimum, lines = 1;
      // Compare one/two lines using the selected face's actual metrics. A
      // slightly long system label may fit one line at 15; a wide display face
      // can use two at 11. Never force every font to a shared smaller size.
      for (
        var candidateLines = 1;
        candidateLines <= allowedLines;
        candidateLines++
      ) {
        final p = TextPainter(
          textDirection: direction,
          textScaler: scaler,
          maxLines: candidateLines,
        );
        bool fits(double size) {
          p.text = TextSpan(
            text: text,
            style: inherited.copyWith(fontSize: size),
          );
          p.layout(maxWidth: width);
          return !p.didExceedMaxLines && p.height <= height;
        }

        var lo = minimum, hi = nominal;
        final minimumFits = fits(minimum);
        if (fits(nominal)) {
          lo = nominal;
        } else {
          for (var i = 0; i < 12; i++) {
            final size = (lo + hi) / 2;
            if (fits(size))
              lo = size;
            else
              hi = size;
          }
        }
        if ((candidateLines == 1 || lo > chosen + .01) && minimumFits) {
          chosen = lo;
          lines = candidateLines;
        }
        p.dispose();
        if (chosen == nominal) break;
      }
      return Text(
        text,
        style: inherited.copyWith(fontSize: chosen),
        maxLines: lines,
        overflow: overflow ?? TextOverflow.ellipsis,
      );
    },
  );
}
