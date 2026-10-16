import 'dart:io';
import 'dart:typed_data';

import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_fit_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'only the overflowing selected face shrinks; fitting fonts keep nominal size',
    (t) async {
      await t.runAsync(() async {
        await (FontLoader('Roboto')..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('test/fixtures/fonts/Roboto.ttf').readAsBytes(),
                ),
              ),
            ))
            .load();
        await (FontLoader('WideDisplayTest')..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('test/fixtures/fonts/WideDisplay.otf')
                      .readAsBytes(),
                ),
              ),
            ))
            .load();
      });
      const label = 'Thiết kế web nâng cao';
      TextStyle face(String family) =>
          TextStyle(fontFamily: family, fontSize: 16, height: 1);
      double width(String family) {
        final p = TextPainter(
          text: TextSpan(text: label, style: face(family)),
          textDirection: TextDirection.ltr,
        )..layout();
        final result = p.width;
        p.dispose();
        return result;
      }

      final systemWidth = width('Roboto'),
          displayWidth = width('WideDisplayTest');
      expect(displayWidth, greaterThan(systemWidth));
      final available = (systemWidth + displayWidth) / 2;
      for (final family in ['Roboto', 'WideDisplayTest']) {
        for (final bound in [available, 700.0]) {
          await t.pumpWidget(
            MaterialApp(
              home: Center(
                child: SizedBox(
                  width: bound,
                  child: WaterFitText(label, style: face(family), maxLines: 1),
                ),
              ),
            ),
          );
          final text = t.widget<Text>(find.text(label));
          expect(text.style!.fontFamily, family);
          if (family == 'WideDisplayTest' && bound == available) {
            expect(text.style!.fontSize, lessThan(16));
          } else {
            expect(text.style!.fontSize, 16);
          }
          expect(t.takeException(), isNull);
        }
      }
    },
  );
}
