import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import 'water_config.dart';
import 'water_editor.dart';
import 'water_surface.dart';

Future<void> showWaterCoolingEditor(BuildContext context) {
  final controller = AppThemeController.instance;
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: WaterCoolingPage.routeName),
      builder: (_) => WaterCoolingPage(
        initial: controller.theme == AppThemeId.waterCooling
            ? controller.waterConfig
            : controller.waterCustom,
      ),
    ),
  );
}

/// The dedicated edit button opens this route. Preview uses the same engine,
/// density contours, sensor input and master RGB clock as the app background.
class WaterCoolingPage extends StatefulWidget {
  const WaterCoolingPage({required this.initial, super.key});
  static const routeName = '/theme/water-cooling';
  final WaterConfig initial;
  @override
  State<WaterCoolingPage> createState() => _WaterCoolingPageState();
}

class _WaterCoolingPageState extends State<WaterCoolingPage> {
  final _editor = GlobalKey<WaterEditorState>();
  bool _expanded = false;
  Widget _preview() => GestureDetector(
    key: const ValueKey('water-live-preview'),
    behavior: HitTestBehavior.opaque,
    onPanUpdate: (details) =>
        WaterScope.of(context)?.physics
            .acceleration(-details.delta.dx * 5, -details.delta.dy * 5),
    child: const WaterReservoirViewport(),
  );
  @override
  Widget build(BuildContext context) {
    final theme = buildBetterTheme(
      appThemePalettes[AppThemeId.waterCooling]!.withFontFamily('Roboto'),
    );
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: SizedBox(
                        height: (constraints.maxHeight * .25).clamp(
                          145.0,
                          210.0,
                        ),
                        child: WaterBlock(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _preview(),
                                const Positioned(
                                  left: 14,
                                  top: 14,
                                  child: IgnorePointer(
                                    child: Text(
                                      'WATER COOLING',
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: IconButton(
                                    tooltip: 'Đóng Water Cooling',
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: IconButton(
                                    tooltip: 'Xem nước toàn màn hình',
                                    onPressed: () =>
                                        setState(() => _expanded = true),
                                    icon: const Icon(
                                      Icons.open_in_full_rounded,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const ValueKey('water-settings-scroll'),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: WaterEditor(
                          key: _editor,
                          initial: widget.initial,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _editor.currentState?.saveAndApply(),
                          icon: const Icon(Icons.power_settings_new),
                          label: const Text('Lưu & Áp dụng'),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_expanded)
                  Positioned.fill(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _preview(),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filledTonal(
                            tooltip: 'Đóng xem trước',
                            onPressed: () => setState(() => _expanded = false),
                            icon: const Icon(Icons.close_fullscreen_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
