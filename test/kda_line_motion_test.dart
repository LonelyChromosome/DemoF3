import 'dart:ui' as ui;
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
  test('one onset launches one inward pair then merges and expires', () {
    final m = KdaLineMotion();
    m.input(List.filled(48, .05), timestampSeconds: 0);
    m.input(List.generate(48, (i) => i < 14 ? .9 : .05), timestampSeconds: .1);
    expect(m.beatCount, 1); expect(m.pulses.length, 1);
    final p = m.pulses.single;
    expect(p.kind, KdaPulseKind.bass);
    m.step(p.duration * .1);
    final start = p.front;
    expect(start, lessThan(.15));
    expect(m.displacement(start, 300, 1), greaterThan(.5));
    expect(m.displacement(1 - start, 300, 1), closeTo(m.displacement(start, 300, 1), 1e-9));
    expect(m.displacement(.5, 300, 1), 0);
    m.step(p.duration * .4);
    expect(p.front, greaterThan(start)); expect(p.front, lessThan(.5));
    expect(m.displacement(start, 300, 1).abs(), lessThan(.01));
    m.step(p.duration * .31);
    expect(p.front, .5); expect(m.displacement(.5, 300, 1), greaterThan(.5));
    final arriving = peak(m);
    m.step(p.duration * .14); expect(peak(m), lessThan(arriving));
    m.step(p.duration * .06);
    expect(m.pulses, isEmpty); expect(peak(m), 0); expect(m.beatCount, 1); m.dispose();
  });
  test('incoming fronts stay mirrored at every position and on narrow cards', () {
    final m = KdaLineMotion();
    m.input(voice(.1), timestampSeconds: 0); m.input(voice(.9), timestampSeconds: .1);
    for (var frame = 0; frame < 30; frame++) {
      m.step(.02);
      for (final width in [80.0, 300.0, 700.0]) {
        for (var i = 0; i <= 100; i++) {
          expect(m.displacement(i / 100, width, 1), closeTo(m.displacement(1 - i / 100, width, 1), 1e-8));
        }
      }
    }
    expect(m.moving, isFalse); m.dispose();
  });
  test('real inter-onset spacing controls bounded travel speed without spawning events', () {
    final fast = KdaLineMotion(), slow = KdaLineMotion();
    for (final m in [fast, slow]) {
      m.input(voice(.1), timestampSeconds: 0); m.input(voice(.9), timestampSeconds: .1);
      m.input(voice(.1), timestampSeconds: .15);
    }
    fast.input(voice(.9), timestampSeconds: .3);
    slow.input(voice(.9), timestampSeconds: 1.1);
    expect(fast.pulses.last.duration, lessThan(slow.pulses.last.duration));
    expect(fast.pulses.last.duration, greaterThanOrEqualTo(.24));
    expect(slow.pulses.last.duration, lessThanOrEqualTo(.56));
    fast.step(1); slow.step(1);
    expect(fast.beatCount, 2); expect(slow.beatCount, 2);
    expect(fast.moving, isFalse); expect(slow.moving, isFalse);
    fast.dispose(); slow.dispose();
  });
  test('dense loud music never exceeds the two dp excursion', () {
    final m = KdaLineMotion();
    for (var i = 0; i < 160; i++) {
      m.input(List.filled(48, i % 3 == 0 ? .95 : .10), timestampSeconds: i * .05);
      m.step(.05);
      expect(m.pulses.length, lessThanOrEqualTo(6));
      for (var j = 0; j < 120; j++) { expect(m.displacement(j / 120, 700, 1.5).abs(), lessThanOrEqualTo(2)); }
    }
    expect(m.beatCount, greaterThan(8)); m.reset(); expect(m.moving, isFalse); m.dispose();
  });
  test('subthreshold changes do not create extra movement between accepted beats', () {
    final m = KdaLineMotion();
    m.input(voice(.3), timestampSeconds: 0);
    m.input(voice(.31), timestampSeconds: .05); m.step(.03);
    expect(m.beatCount, 0); expect(peak(m), 0); expect(m.moving, isFalse);
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
  test('paint mirrors top and bottom and never leaks into neighbouring cards', () async {
    final m = KdaLineMotion();
    m.input(voice(.1), timestampSeconds: 0); m.input(voice(.9), timestampSeconds: .1);
    m.step(.12);
    for (final size in [const Size(300, 110), const Size(180, 280)]) {
      final recorder = ui.PictureRecorder(); final canvas = Canvas(recorder);
      canvas.translate(10, 10);
      KdaLinePainter(m, Colors.pink, 18, 1.5).paint(canvas, size);
      final picture = recorder.endRecording();
      final width = size.width.toInt() + 20, height = size.height.toInt() + 20;
      final image = await picture.toImage(width, height);
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var mirrorDifference = 0.0;
      int alpha(int x, int y) => data.getUint8((y * width + x) * 4 + 3);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          if (x < 10 || x >= width - 10 || y < 10 || y >= height - 10) {
            expect(alpha(x, y), 0);
          }
          mirrorDifference += (alpha(x, y) - alpha(width - 1 - x, y)).abs();
          mirrorDifference += (alpha(x, y) - alpha(x, height - 1 - y)).abs();
        }
      }
      expect(mirrorDifference / (width * height * 2), lessThan(1));
      image.dispose(); picture.dispose();
    }
    m.dispose();
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
