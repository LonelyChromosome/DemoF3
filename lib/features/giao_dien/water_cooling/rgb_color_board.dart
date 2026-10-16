import 'package:flutter/material.dart';

class RgbColorBoard extends StatefulWidget {
  const RgbColorBoard({
    required this.initial,
    required this.onChanged,
    super.key,
  });
  final Color initial;
  final ValueChanged<Color> onChanged;
  @override
  State<RgbColorBoard> createState() => _RgbColorBoardState();
}

class _RgbColorBoardState extends State<RgbColorBoard> {
  late Color color = widget.initial;
  late final hex = TextEditingController(text: _hex(color));
  String _hex(Color c) =>
      c.toARGB32().toRadixString(16).substring(2).toUpperCase();
  void choose(Color c) {
    setState(() {
      color = c;
      hex.text = _hex(c);
    });
    widget.onChanged(c);
  }

  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      LayoutBuilder(
        builder: (c, box) => GestureDetector(
          key: const ValueKey('rgb-gamut-board'),
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => touch(d.localPosition, box.maxWidth),
          onPanUpdate: (d) => touch(d.localPosition, box.maxWidth),
          child: SizedBox(
            height: 190,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(painter: _GamutPainter(color)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 4,
        children: [
          for (final c in const [
            Color(0xFFAC70FF),
            Color(0xFFFF4DAD),
            Color(0xFFEE315E),
            Color(0xFF5F38A8),
            Colors.white,
            Color(0xFFFF7F50),
            Color(0xFF407BFF),
            Color(0xFF42DFBA),
          ])
            IconButton(
              tooltip: '#${_hex(c)}',
              onPressed: () => choose(c),
              icon: Icon(Icons.circle, color: c, size: 26),
            ),
        ],
      ),
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: hex,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Mã màu RGB',
                prefixText: '#',
                counterText: '',
              ),
              onChanged: (s) {
                final n = int.tryParse(s, radix: 16);
                if (s.length == 6 && n != null) {
                  setState(() => color = Color(0xFF000000 | n));
                  widget.onChanged(color);
                }
              },
            ),
          ),
        ],
      ),
    ],
  );
  void touch(Offset p, double w) {
    final x = (p.dx / w).clamp(0.0, 1.0), y = (p.dy / 190).clamp(0.0, 1.0);
    choose(
      HSVColor.fromAHSV(
        1,
        x * 359.99,
        (y * 2).clamp(0, 1),
        (2 - y * 2).clamp(0, 1),
      ).toColor(),
    );
  }
}

class _GamutPainter extends CustomPainter {
  _GamutPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size,
        pen = Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFFFF00),
              Color(0xFF00FF00),
              Color(0xFF00FFFF),
              Color(0xFF0000FF),
              Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ],
          ).createShader(Offset.zero & size);
    canvas.drawRect(rect, pen);
    pen.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Color(0x00FFFFFF),
        Color(0x00000000),
        Colors.black,
      ],
      stops: [0, .5, .5, 1],
    ).createShader(rect);
    canvas.drawRect(rect, pen);
    final h = HSVColor.fromColor(color),
        p = Offset(
          h.hue / 360 * size.width,
          (h.saturation < .999 ? h.saturation / 2 : 1 - h.value / 2) *
              size.height,
        );
    pen
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.black;
    canvas.drawCircle(p, 8, pen);
    pen
      ..strokeWidth = 1.5
      ..color = Colors.white;
    canvas.drawCircle(p, 8, pen);
  }

  @override
  bool shouldRepaint(_GamutPainter old) => old.color != color;
}
