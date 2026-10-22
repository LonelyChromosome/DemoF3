import 'package:flutter/material.dart';
import 'kda_runtime.dart';

Future<void> showKdaSettings(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => const SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
    child: KdaSettings(),
  ),
);

class KdaSettings extends StatelessWidget {
  const KdaSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final runtime = KdaRuntime.instance;
    return AnimatedBuilder(
      animation: runtime,
      builder: (context, _) {
        final config = runtime.config;
        Future<void> save(KdaConfig value) async {
          try {
            await runtime.save(value);
          } on Object {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không lưu được thiết lập')),
              );
            }
          }
        }

        return Material(
          type: MaterialType.transparency,
          child: Column(
            key: const ValueKey('kda-theme-settings'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('K/DA FIRESTARTER',
                    style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(
                  key: const ValueKey('kda-settings-close'),
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              SwitchListTile.adaptive(
                key: const ValueKey('kda-setting-video'),
                title: const Text('Video nền'),
                value: config.video,
                onChanged: (value) => save(config.copyWith(video: value)),
              ),
              SwitchListTile.adaptive(
                key: const ValueKey('kda-setting-music'),
                title: const Text('Nhạc'),
                value: config.music,
                onChanged: (value) => save(config.copyWith(music: value)),
              ),
              SwitchListTile.adaptive(
                title: const Text('Phổ âm'),
                value: config.visualizer,
                onChanged: (value) => save(config.copyWith(visualizer: value)),
              ),
              if (config.visualizer) ...[
                if (!runtime.permission)
                  TextButton.icon(
                    icon: const Icon(Icons.mic_none_rounded),
                    label: const Text('Cấp quyền ghi âm'),
                    onPressed: runtime.requestPermission,
                  ),
                SwitchListTile.adaptive(
                  title: const Text('Tiêu đề'),
                  value: config.marquee,
                  onChanged: (value) => save(config.copyWith(marquee: value)),
                ),
                Row(children: [
                  const Text('Cường độ'),
                  Expanded(child: Slider(
                    value: config.intensity,
                    min: .35,
                    max: 1.5,
                    onChanged: (value) => save(config.copyWith(intensity: value)),
                  )),
                ]),
              ],
              if (runtime.error != null)
                const Text('Không phát được video',
                    style: TextStyle(color: Color(0xFFFFC4CC))),
            ],
          ),
        );
      },
    );
  }
}
