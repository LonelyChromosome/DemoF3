import 'package:better_phenikaa_schedule/features/giao_dien/kda_firestarter/kda_line_motion.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/kda_firestarter/kda_line_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> voice(double value) => List.generate(48, (i) => i >= 14 && i < 37 ? value : .12);
double peak(KdaLineMotion m) => List.generate(160, (i) => m.displacement(i / 160, 900, 1).abs()).reduce((a, b) => a > b ? a : b);

void main() {
  test('silence and noise do not invent musical events', () {
    final m = KdaLineMotion();
    for (var i = 0; i < 100; i++) {
      m.input(List.filled(48, .02), timestampSeconds: i * .05); m.step(.05);
    }
    expect(m.beatCount, 0); expect(m.moving, isFalse); expect(peak(m), 0);
    m.dispose();
  });
  test('held sound has no free-running carrier, even while captures continue', () {
    final m = KdaLineMotion();
    m.input(List.filled(48, .08), timestampSeconds: 0);
    m.input(voice(.7), timestampSeconds: .1); m.step(.03);
    expect(m.beatCount, 1); expect(peak(m), greaterThan(.05));
    for (var i = 1; i < 100; i++) { m.input(voice(.7), timestampSeconds: .1 + i * .05); m.step(.05); }
    expect(m.beatCount, 1); expect(m.pulses, isEmpty);
    expect(m.moving, isFalse); expect(peak(m), 0);
    // Rendering more frames cannot advance a carrier or create another beat.
    for (var i = 0; i < 100; i++) { m.step(.03); }
    expect(m.beatCount, 1); expect(peak(m), 0); m.dispose();
  });
  test('fast midrange syllable attacks create more packets with the same bass', () {
    final fast = KdaLineMotion(), slow = KdaLineMotion();
    for (var i = 0; i < 200; i++) {
      final t = i * .05;
      fast.input(voice(i % 4 == 1 ? .75 : .12), timestampSeconds: t);
      slow.input(voice(i % 20 == 1 ? .75 : .12), timestampSeconds: t);
      fast.step(.05); slow.step(.05);
    }
    expect(fast.beatCount, greaterThan(slow.beatCount * 3));
    expect(fast.density, greaterThan(slow.density));
    expect(fast.pulses.every((p) => p.kind == KdaPulseKind.vocal), isTrue);
    fast.dispose(); slow.dispose();
  });
  test('capture timing determines rhythm independently of display frame rate', () {
    final a = KdaLineMotion(), b = KdaLineMotion();
    for (var i = 0; i < 60; i++) {
      final bands = voice([2, 7, 11, 23, 24, 35, 49].contains(i) ? .8 : .12);
      a.input(bands, timestampSeconds: i * .1);
      b.input(bands, timestampSeconds: i * .1);
      for (var j = 0; j < 6; j++) { a.step(1 / 60); }
      for (var j = 0; j < 3; j++) { b.step(1 / 30); }
      expect(a.beatCount, b.beatCount); expect(a.density, b.density);
    }
    expect(a.beatCount, greaterThan(3)); a.dispose(); b.dispose();
  });
  test('a bass hit rings locally then damps without circulating around the border', () {
    final m = KdaLineMotion();
    m.input(List.filled(48, .05), timestampSeconds: 0);
    m.input(List.generate(48, (i) => i < 14 ? .9 : .05), timestampSeconds: .1);
    m.step(.025); expect(peak(m), greaterThan(.15));
    expect(m.pulses.single.kind, KdaPulseKind.bass);
    final first = m.pulses.single.response;
    m.step(.075); expect(m.pulses.single.response.sign, isNot(first.sign));
    for (var i = 0; i < 30; i++) { m.step(.05); }
    expect(m.pulses, isEmpty); expect(peak(m), 0); m.dispose();
  });
  test('dense loud music never exceeds the reduced three dp excursion', () {
    final m = KdaLineMotion();
    for (var i = 0; i < 160; i++) {
      m.input(List.filled(48, i % 3 == 0 ? .95 : .10), timestampSeconds: i * .05);
      m.step(.05);
      expect(m.pulses.length, lessThanOrEqualTo(6));
      for (var j = 0; j < 120; j++) { expect(m.displacement(j / 120, 700, 1.5).abs(), lessThanOrEqualTo(3)); }
    }
    expect(m.beatCount, greaterThan(8)); m.reset(); expect(m.moving, isFalse); m.dispose();
  });
  test('small measured changes can move a held note gently without new bass beats', () {
    final m = KdaLineMotion();
    m.input(voice(.3), timestampSeconds: 0);
    m.input(voice(.31), timestampSeconds: .05); m.step(.03);
    expect(m.beatCount, 0); expect(peak(m), greaterThan(0)); expect(peak(m), lessThan(.1));
    for (var i = 1; i < 80; i++) { m.input(voice(.31), timestampSeconds: .05 + i * .05); m.step(.05); }
    expect(peak(m), 0); m.dispose();
  });
  test('changes in a few vocal harmonics are not lost in a band average', () {
    final m=KdaLineMotion();final before=voice(.12),after=voice(.12);
    for(final i in [17,23,29]){after[i]=.20;}
    m.input(before,timestampSeconds:0);m.input(after,timestampSeconds:.1);m.step(.02);
    expect(m.beatCount,1);expect(m.pulses.single.kind,KdaPulseKind.vocal);m.dispose();
  });
  test('a delayed render frame does not slow musical time or keep a hit alive', () {
    final m=KdaLineMotion();
    m.input(voice(.12),timestampSeconds:0);m.input(voice(.8),timestampSeconds:.1);m.step(.02);
    expect(m.pulses,isNotEmpty);m.step(1);
    expect(m.pulses,isEmpty);expect(m.moving,isFalse);expect(peak(m),0);m.dispose();
  });
  test('invalid FFT values cannot produce invalid geometry', () {
    final m = KdaLineMotion(); m.input([double.nan, double.infinity, -1, 2]); m.step(.03);
    expect(m.energy.isFinite, isTrue); expect(m.displacement(.5, 1, 1.5).isFinite, isTrue); m.dispose();
  });
  testWidgets('border repaint keeps card geometry, content and hitbox intact', (tester) async {
    final m = KdaLineMotion(); var builds = 0, taps = 0;
    await tester.pumpWidget(MaterialApp(home: Center(child: KdaLineScope(motion: m,
      child: KdaLineBorder(color: Colors.pink, radius: 18, child: Builder(builder: (_) {
        builds++; return SizedBox(width: 300, height: 110, child: TextButton(onPressed: () => taps++, child: const Text('Card')));
      })),
    ))));
    final size = tester.getSize(find.byType(KdaLineBorder));
    m.input(voice(.1), timestampSeconds: 0); m.input(voice(.9), timestampSeconds: .1); m.step(.025);
    await tester.pump(); expect(builds, 1); expect(tester.getSize(find.byType(KdaLineBorder)), size);
    await tester.tap(find.text('Card')); expect(taps, 1);
    for (var i = 0; i < 60; i++) { m.step(.03); }
    await tester.pump(); expect(m.moving, isFalse); expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox()); m.dispose();
  });
}
