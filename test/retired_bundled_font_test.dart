import 'package:better_phenikaa_schedule/features/giao_dien/phong_chu/font_choice.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/water_cooling/water_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retired bundled face disappears and old saved settings retain other choices', () {
    expect(AppFontChoice.builtIns.any((f) => f.id == 'batman_forever'), false);
    final old = AppFontChoice.fromJson({
      'id': 'batman_forever',
      'family': 'BatmanForever',
      'kind': 'builtIn',
    });
    expect(old, AppFontChoice.system);
    final data = const WaterConfig().patch({
      'fill': .18,
      'mode': 'beam',
    }).toJson()..['fontId'] = 'batman_forever';
    final restored = WaterConfig.fromJson(Map<String, dynamic>.from(data));
    expect(restored.font, AppFontChoice.system);
    expect(restored.fill, .18);
    expect(restored.mode, LedMode.beam);
  });
  test(
    'user imported font files are preserved even with the same family name',
    () {
      final imported = AppFontChoice.fromJson({
        'id': 'imported:custom',
        'family': 'BatmanForever',
        'kind': 'imported',
        'path': '/user/font.otf',
      });
      expect(imported.kind, AppFontKind.imported);
      expect(imported.path, '/user/font.otf');
    },
  );
}
