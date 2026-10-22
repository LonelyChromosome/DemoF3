import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An isolated simulator: independent fake timetable/clock/notifications.
class VehicleFakePanel extends StatefulWidget {
  const VehicleFakePanel({super.key});

  @override
  State<VehicleFakePanel> createState() => _VehicleFakePanelState();
}

class _VehicleFakePanelState extends State<VehicleFakePanel> {
  static const _channel = MethodChannel('better_phenikaa/vehicle');
  Map<String, dynamic> data = <String, dynamic>{};
  bool busy = false;
  String feedback = '';

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
      final state = await _channel.invokeMethod<dynamic>('fakeState');
      if (mounted) {
        setState(() => data = Map<String, dynamic>.from(state as Map));
      }
    } on PlatformException catch (error) {
      if (mounted) setState(() => feedback = error.message ?? error.code);
    }
  }

  Future<void> _event(String action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await _channel.invokeMethod<String>(
        'fakeAction', <String, String>{'action': action});
      if (mounted) setState(() => feedback = result ?? 'Đã chạy mô phỏng');
      await _read();
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => feedback = error.message ?? error.code);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _hour(int timestamp) {
    final t = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return t.hour.toString().padLeft(2, '0') + ':' +
        t.minute.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final state = data['status']?.toString() ?? 'Đang nạp...';
    final waiting = data['waiting'] is List
        ? data['waiting'] as List
        : const <dynamic>[];
    final excluded = data['excluded'] is List
        ? data['excluded'] as List
        : const <dynamic>[];
    final history = data['history'] is List
        ? data['history'] as List
        : const <dynamic>[];
    final anyAvailable = waiting.any((raw) =>
        raw is Map && raw['available'] == true);
    final clock = (data['virtualTime'] as num?)?.toInt();
    final isWaiting = state == 'WAITING';
    final isTracking = state == 'TRACKING';
    final isParked = state == 'PARKED';
    final color = palette.textPrimary;
    final muted = palette.textSecondary;

    Widget control(
      String label, IconData icon, String action, bool allowed,
    ) {
      return OutlinedButton.icon(
        onPressed: busy || !allowed ? null : () => _event(action),
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Divider(color: palette.border),
        Row(children: <Widget>[
          Icon(Icons.science_rounded, size: 19, color: palette.primary),
          const SizedBox(width: 7),
          Expanded(child: Text('MÔ PHỎNG 100% FAKE',
            style: TextStyle(color: color, fontWeight: FontWeight.w800,
                fontSize: 13))),
        ]),
        const SizedBox(height: 5),
        Text('Không GPS · không đổi giờ điện thoại · không đụng phiên xe thật. '
             'Thông báo đều mang nhãn [FAKE TEST].',
          style: TextStyle(color: muted, fontSize: 11)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: .09),
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Đồng hồ mô phỏng: ' +
                  (clock == null ? '—' : _hour(clock)),
                style: TextStyle(color: color, fontWeight: FontWeight.w700,
                    fontSize: 12)),
              const SizedBox(height: 4),
              Text('Trạng thái: ' + state,
                style: TextStyle(color: muted, fontSize: 12)),
              if ((data['current']?.toString() ?? '').isNotEmpty)
                Text('Lượt đang xử lý: ' + data['current'].toString(),
                  style: TextStyle(color: muted, fontSize: 11)),
            ]),
        ),
        const SizedBox(height: 12),
        Text('Hàng chờ FAKE · dấu ✓/✕',
          style: TextStyle(color: color, fontWeight: FontWeight.w700,
              fontSize: 12)),
        const SizedBox(height: 8),
        if (waiting.isEmpty)
          Text('Không còn buổi nào trong hàng chờ.',
            style: TextStyle(color: muted, fontSize: 12)),
        for (final raw in waiting)
          if (raw is Map)
            Builder(builder: (context) {
              final item = Map<String, dynamic>.from(raw);
              final available = item['available'] == true;
              final start = (item['start'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(available ? Icons.check_circle : Icons.cancel,
                      color: available ? const Color(0xFF38BE89) : muted,
                      size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(item['name']?.toString() ?? 'Môn học',
                          style: TextStyle(color: color,
                            fontWeight: FontWeight.w600, fontSize: 12)),
                        Text(_hour(start) + ' · ' +
                            (item['status']?.toString() ?? ''),
                          style: TextStyle(color: muted, fontSize: 11)),
                      ]),
                    )),
                  ]),
              );
            }),
        if (excluded.isNotEmpty) ...<Widget>[
          const SizedBox(height: 3),
          for (final item in excluded)
            Row(children: <Widget>[
              Icon(Icons.block, size: 18, color: muted),
              const SizedBox(width: 8),
              Expanded(child: Text(
                item.toString() + ' — KHÔNG vào hàng chờ',
                style: TextStyle(color: muted, fontSize: 11)),
              ),
            ]),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 6, children: <Widget>[
          control('Vào phạm vi', Icons.meeting_room_outlined,
            'gate', isWaiting && anyAvailable),
          control('Đã đỗ xe', Icons.two_wheeler,
            'park', isTracking),
          control('Xe ra cổng', Icons.logout,
            'exit', isParked),
          control('Hết giờ, chưa đỗ', Icons.timer_off_outlined,
            'expire', !isParked && (isTracking || anyAvailable)),
          control('Môn tiếp theo', Icons.skip_next,
            'next', isWaiting),
          control('Đặt lại toàn bộ FAKE', Icons.restart_alt,
            'reset', true),
        ]),
        if (feedback.isNotEmpty) ...<Widget>[
          const SizedBox(height: 9),
          Text(feedback, style: TextStyle(color: palette.primary,
            fontSize: 12, fontWeight: FontWeight.w600)),
        ],
        if (history.isNotEmpty) ...<Widget>[
          const SizedBox(height: 11),
          Text('Nhật ký sự kiện FAKE',
            style: TextStyle(color: color,
              fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          for (final entry in history.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(entry.toString(),
                style: TextStyle(color: muted, fontSize: 11))),
        ],
      ],
    );
  }
}
