import 'dart:async';

import 'package:better_phenikaa_schedule/features/app_update/update_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class UpdateFlowSheet extends StatefulWidget {
  const UpdateFlowSheet({required this.controller, super.key});
  final UpdateController controller;

  @override
  State<UpdateFlowSheet> createState() => _UpdateFlowSheetState();
}

class _UpdateFlowSheetState extends State<UpdateFlowSheet> {
  Timer? _hold;
  bool _holding = false;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  void _beginHold(PointerDownEvent _) {
    if (_holding) return;
    setState(() => _holding = true);
    _hold = Timer(const Duration(seconds: 2), () {
      _holding = false;
      unawaited(widget.controller.startManualAfterHold());
      if (mounted) setState(() {});
    });
  }

  void _endHold(PointerEvent _) {
    _hold?.cancel();
    if (mounted) setState(() => _holding = false);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final notice = controller.notice;
      final phase = controller.phase;
      final progress = controller.total > 0
          ? (controller.downloaded / controller.total).clamp(0.0, 1.0)
          : null;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Cập nhật Better Phenikaa',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                notice == null
                    ? 'Chưa có bản cập nhật.'
                    : '${notice.versionName} · ${notice.notes}',
              ),
              const SizedBox(height: 20),
              if (phase == UpdatePhase.available ||
                  phase == UpdatePhase.cancelled ||
                  phase == UpdatePhase.failed ||
                  phase == UpdatePhase.notAvailable) ...[
                FilledButton.icon(
                  onPressed: notice == null ? null : controller.startCard,
                  icon: const Icon(Icons.nfc_rounded),
                  label: const Text('Cập nhật bằng thẻ'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: notice == null
                      ? null
                      : () => setState(() => _manualSummary = true),
                  child: const Text('Cập nhật thủ công'),
                ),
                if (_manualSummary) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Giữ 2 giây để tải và cài ${notice?.versionName ?? "bản mới"}.',
                  ),
                  const SizedBox(height: 8),
                  Listener(
                    onPointerDown: _beginHold,
                    onPointerUp: _endHold,
                    onPointerCancel: _endHold,
                    child: FilledButton.tonal(
                      onPressed: () {},
                      child: Text(_holding ? 'Đang giữ…' : 'Giữ để tiếp tục'),
                    ),
                  ),
                ],
              ],
              if (phase == UpdatePhase.waitingForCard ||
                  phase == UpdatePhase.wrongCard)
                Text(
                  phase == UpdatePhase.wrongCard
                      ? 'Không đúng thẻ'
                      : 'Đưa thẻ NFC lại gần điện thoại.',
                ),
              if (phase == UpdatePhase.downloading) ...[
                const Text('Đang tải bản cập nhật'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
                Text(
                  controller.total > 0
                      ? '${(100 * (progress ?? 0)).toStringAsFixed(0)}% · '
                            '${controller.downloaded ~/ 1024} / ${controller.total ~/ 1024} KB'
                      : '',
                ),
              ],
              if (phase == UpdatePhase.verifying) const Text('Đang xác minh'),
              if (phase == UpdatePhase.readyForInstaller)
                const Text('Đang chuẩn bị cài đặt'),
              if (phase == UpdatePhase.installerLaunched)
                const Text('Tiếp tục trên màn hình cài đặt của Android.'),
              if (phase == UpdatePhase.installed)
                const Text('Đã cài bản cập nhật.'),
              if (phase == UpdatePhase.permissionRequired) ...[
                const Text(
                  'Android cần cho phép Better Phenikaa yêu cầu cài đặt. '
                  'Bạn có thể từ chối và tiếp tục dùng app bình thường.',
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: controller.openInstallSettings,
                  child: const Text('Mở cài đặt Android'),
                ),
              ],
              if (controller.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              if (phase != UpdatePhase.installerLaunched)
                TextButton(
                  onPressed: () {
                    unawaited(controller.cancel());
                    Navigator.of(context).pop();
                  },
                  child: const Text('Đóng'),
                ),
            ],
          ),
        ),
      );
    },
  );

  bool _manualSummary = false;
}
