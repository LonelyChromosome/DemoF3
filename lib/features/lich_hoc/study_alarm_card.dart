import 'package:better_phenikaa_schedule/features/dang_nhap_qldt/qldt_models.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The previous whole hour is *strictly before* the start of class.
/// 09:30 -> 09:00, 13:00 -> 12:00, 00:00 -> 23:00.
int studyAlarmDefaultHour(DateTime startAt) =>
    (startAt.hour - (startAt.minute == 0 ? 1 : 0) + 24) % 24;

class StudyAlarmCard extends StatefulWidget {
  const StudyAlarmCard({
    required this.item,
    required this.content,
    super.key,
  });

  final ScheduleRecord item;
  final Widget content;

  static final ValueNotifier<String?> _openItem = ValueNotifier<String?>(null);

  /// Allows the app's existing system-back handler to dismiss the picker.
  static bool dismissExpanded() {
    if (_openItem.value == null) return false;
    _openItem.value = null;
    return true;
  }

  @override
  State<StudyAlarmCard> createState() => _StudyAlarmCardState();
}

class _StudyAlarmCardState extends State<StudyAlarmCard> {
  static const _channel = MethodChannel('better_phenikaa/study_alarm');
  static const _duration = Duration(milliseconds: 250);

  late FixedExtentScrollController _hours;
  late FixedExtentScrollController _minutes;
  late int _hour;
  int _minute = 0;
  bool _sending = false;

  String get _identity =>
      '${widget.item.id}|${widget.item.startAt.toIso8601String()}';

  @override
  void initState() {
    super.initState();
    _resetPicker();
  }

  void _resetPicker() {
    _hour = studyAlarmDefaultHour(widget.item.startAt);
    _minute = 0;
    _hours = FixedExtentScrollController(initialItem: 24 * 500 + _hour);
    _minutes = FixedExtentScrollController(initialItem: 60 * 500);
  }

  @override
  void didUpdateWidget(covariant StudyAlarmCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.startAt != widget.item.startAt) {
      _hours.dispose();
      _minutes.dispose();
      _resetPicker();
    }
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _open() {
    _hours.dispose();
    _minutes.dispose();
    _resetPicker();
    StudyAlarmCard._openItem.value = _identity;
  }

  Future<void> _confirm() async {
    if (_sending) return;
    setState(() => _sending = true);
    final hour = _hour;
    final minute = _minute;
    final label = 'BPA - ${widget.item.subjectName}';
    try {
      final dispatched = await _channel.invokeMethod<bool>('setAlarm', <String, Object>{
        'hour': hour,
        'minute': minute,
        'label': label,
      });
      if (!mounted) return;
      if (dispatched != true) {
        throw const PlatformException(
          code: 'clock_failed',
          message: 'Không gửi được yêu cầu tới Đồng hồ.',
        );
      }
      StudyAlarmCard.dismissExpanded();
      final time = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Đã gửi yêu cầu đặt báo thức $time tới Đồng hồ'),
          duration: const Duration(seconds: 2),
        ));
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(error.message ?? 'Không thể đặt báo thức.'),
          duration: const Duration(seconds: 3),
        ));
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thiết bị chưa hỗ trợ đặt báo thức.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Color _contrastingAccent(AppThemePalette palette) {
    final background = palette.card;
    final accent = palette.primary;
    final l1 = background.computeLuminance();
    final l2 = accent.computeLuminance();
    final ratio = (l1 > l2 ? (l1 + .05) / (l2 + .05) : (l2 + .05) / (l1 + .05));
    if (ratio >= 4.0) return accent;
    final fallback = palette.textPrimary;
    final f = fallback.computeLuminance();
    final fallbackRatio = (l1 > f ? (l1 + .05) / (f + .05) : (f + .05) / (l1 + .05));
    if (fallbackRatio >= 4.0) return fallback;
    return l1 > .4 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final palette = appThemePalette;
    final accent = _contrastingAccent(palette);
    return ValueListenableBuilder<String?>(
      valueListenable: StudyAlarmCard._openItem,
      builder: (context, current, _) {
        final expanded = current == _identity;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragEnd: expanded
                      ? (details) {
                          if ((details.primaryVelocity ?? 0) > 320) {
                            StudyAlarmCard.dismissExpanded();
                          }
                        }
                      : null,
                  child: widget.content,
                ),
                Positioned(
                  right: 21,
                  top: 43,
                  child: Semantics(
                    button: true,
                    label: expanded ? 'Xác nhận báo thức' : 'Đặt báo thức',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: ValueKey<String>(
                          expanded ? 'alarm-confirm-${widget.item.id}' : 'alarm-open-${widget.item.id}',
                        ),
                        onTap: _sending ? null : (expanded ? _confirm : _open),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: .055),
                            border: Border.all(
                              color: accent.withValues(alpha: .72),
                              width: 1.35,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(scale: animation, child: child),
                            ),
                            child: _sending
                                ? SizedBox(
                                    key: const ValueKey<String>('busy'),
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: accent,
                                    ),
                                  )
                                : Icon(
                                    expanded ? Icons.check_rounded : Icons.alarm_outlined,
                                    key: ValueKey<bool>(expanded),
                                    color: accent,
                                    size: 24,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              alignment: Alignment.topCenter,
              duration: _duration,
              curve: Curves.easeInOutCubic,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 15),
                      child: Center(
                        child: SizedBox(
                          height: 144,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _WheelColumn(
                                key: const ValueKey<String>('hours'),
                                controller: _hours,
                                count: 24,
                                selected: _hour,
                                color: accent,
                                onChanged: (value) => setState(() => _hour = value),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(':',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _WheelColumn(
                                key: const ValueKey<String>('minutes'),
                                controller: _minutes,
                                count: 60,
                                selected: _minute,
                                color: accent,
                                onChanged: (value) => setState(() => _minute = value),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.controller,
    required this.count,
    required this.selected,
    required this.color,
    required this.onChanged,
    super.key,
  });

  final FixedExtentScrollController controller;
  final int count;
  final int selected;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 91,
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 48,
          diameterRatio: 100,
          perspective: .001,
          squeeze: 1,
          overAndUnderCenterOpacity: .33,
          physics: const FixedExtentScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          onSelectedItemChanged: (index) => onChanged(index % count),
          childDelegate: ListWheelChildLoopingListDelegate(
            children: List<Widget>.generate(count, (index) {
              final focused = index == selected;
              return Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: color.withValues(alpha: focused ? 1 : .72),
                    fontSize: focused ? 34 : 31,
                    fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
                    height: 1,
                  ),
                ),
              );
            }),
          ),
        ),
      );
}
