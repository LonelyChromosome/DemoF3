import 'dart:async';

import 'package:better_phenikaa_schedule/features/app_update/update_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class UpdateFlowSheet extends StatefulWidget {
  const UpdateFlowSheet({required this.controller, required this.displayName, super.key});
  final UpdateController controller;
  final String displayName;

  @override
  State<UpdateFlowSheet> createState() => _UpdateFlowSheetState();
}

class _UpdateFlowSheetState extends State<UpdateFlowSheet> {
  Timer? _hold;
  bool _holding = false;
  final TextEditingController _manualName = TextEditingController();
  bool get _nameMatches => widget.displayName.trim().isNotEmpty &&
      _manualName.text.trim() == widget.displayName.trim();

  @override
  void dispose() {
    _hold?.cancel();
    _manualName.dispose();
    if (widget.controller.phase == UpdatePhase.waitingForCard ||
        widget.controller.phase == UpdatePhase.wrongCard) {
      unawaited(widget.controller.cancel());
    }
    super.dispose();
  }

  void _beginHold(PointerDownEvent _) {
    if (_holding || !_nameMatches) return;
    setState(() => _holding = true);
    _hold = Timer(const Duration(seconds: 2), () {
      _holding = false;
      if (_nameMatches) unawaited(widget.controller.startManualAfterHold());
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
                    'Nhập đúng họ tên trong Tài khoản rồi giữ 2 giây để cập nhật ${notice?.versionName ?? "bản mới"}.',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _manualName,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                  ),
                  const SizedBox(height: 8),
                  Listener(
                    onPointerDown: _beginHold,
                    onPointerUp: _endHold,
                    onPointerCancel: _endHold,
                    child: FilledButton.tonal(
                      onPressed: _nameMatches ? () {} : null,
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

class CardBindingSheet extends StatefulWidget {
  const CardBindingSheet({required this.controller, super.key});
  final UpdateController controller;

  @override
  State<CardBindingSheet> createState() => _CardBindingSheetState();
}

class _CardBindingSheetState extends State<CardBindingSheet> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshCardBinding());
  }

  @override
  void dispose() {
    unawaited(widget.controller.stopBindingCard());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Thẻ cập nhật', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(controller.hasBoundCard
                  ? 'Đã liên kết một thẻ với thiết bị này.'
                  : controller.bindingCard
                      ? 'Đưa thẻ NFC lại gần điện thoại.'
                      : 'Quét thẻ để liên kết với thiết bị này.'),
              if (!controller.hasBoundCard && !controller.bindingCard) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: controller.startBindingCard,
                  icon: const Icon(Icons.nfc_rounded),
                  label: const Text('Liên kết thẻ'),
                ),
              ],
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                Text(controller.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
