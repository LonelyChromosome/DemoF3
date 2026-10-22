import 'package:better_phenikaa_schedule/features/giao_dien/kda_firestarter/kda_line_motion.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/kda_firestarter/kda_line_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('silence and noise floor remain a straight line without synthetic beats', () {
    final m = KdaLineMotion();
    for (var i = 0; i < 150; i++) { m.input(List.filled(48, .02)); m.step(1 / 30); }
    expect(m.pulses, isEmpty); expect(m.energy, 0);
    expect(m.displacement(.3, 900, 1), 0);
    m.dispose();
  });
  test('a real onset travels, splits, stays bounded and returns exactly flat', () {
    final m = KdaLineMotion();
    m.input(List.filled(48, .9)); m.step(.1);
    expect(m.beatCount, 1);
    final first = List.generate(120, (i) => m.displacement(i / 120, 900, 1));
    expect(first.any((v) => v.abs() > .1), isTrue);
    for (var i = 0; i < 4; i++) { m.step(1 / 30); }
    final next = List.generate(120, (i) => m.displacement(i / 120, 900, 1));
    expect(next, isNot(equals(first)));
    for (var i = 0; i < 120; i++) { m.step(1 / 30); }
    expect(m.moving, isFalse);
    for (var i = 0; i < 100; i++) { expect(m.displacement(i / 100, 900, 1), 0); }
    m.dispose();
  });
  test('kicks and sustained loud passages increase response without unbounded waves', () {
    final m = KdaLineMotion();
    for (var i = 0; i < 240; i++) {
      final kick = i % 15 < 3;
      m.input(List.generate(48, (b) => b < 14 && kick ? 1 : .65)); m.step(1 / 30);
      expect(m.pulses.length, lessThanOrEqualTo(4));
      for (var j = 0; j < 100; j++) { expect(m.displacement(j / 100, 700, 1.5).abs(), lessThanOrEqualTo(6)); }
    }
    expect(m.beatCount, greaterThan(5)); expect(m.climax, greaterThan(.7));
    m.reset(); expect(m.moving, isFalse); expect(m.climax, 0);
    m.dispose();
  });
  test('invalid FFT values cannot produce invalid geometry', () {
    final m = KdaLineMotion();
    m.input([double.nan, double.infinity, -1, 2]); m.step(.03);
    expect(m.energy.isFinite, isTrue);
    expect(m.displacement(.5, 1, 1.5).isFinite, isTrue);
    m.dispose();
  });
  testWidgets('border repaints without rebuilding or intercepting card controls', (tester) async {
    final m = KdaLineMotion(); var builds = 0, taps = 0;
    await tester.pumpWidget(MaterialApp(home: Center(child: KdaLineScope(motion: m,
      child: KdaLineBorder(color: Colors.pink, radius: 18, child: Builder(builder: (_) {
        builds++; return SizedBox(width: 300, height: 110, child: TextButton(onPressed: () => taps++, child: const Text('Card')));
      })),
    ))));
    final size = tester.getSize(find.byType(KdaLineBorder));
    m.input(List.filled(48, .9)); m.step(.1); await tester.pump();
    expect(builds, 1); expect(tester.getSize(find.byType(KdaLineBorder)), size);
    await tester.tap(find.text('Card')); expect(taps, 1);
    for (var i = 0; i < 90; i++) { m.step(1 / 30); }
    await tester.pump(); expect(m.moving, isFalse); expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox()); m.dispose();
  });
}
