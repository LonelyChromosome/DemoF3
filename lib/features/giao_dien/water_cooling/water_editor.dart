import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../du_lieu/widget_theme_configuration.dart';
import '../phong_chu/font_choice.dart';
import '../tep_cuc_bo/local_file_bridge.dart';
import '../tep_cuc_bo/file_bytes.dart';
import '../xem_truoc/native_widget_preview.dart';
import '../xem_truoc/widget_image_crop_editor.dart';
import 'water_config.dart';
import 'water_engine.dart';
import 'water_surface.dart';
import 'rgb_color_board.dart';

/// Water-only controls; the page owns the persistent reservoir preview/footer.
class WaterEditor extends StatefulWidget {
  const WaterEditor({this.initial, super.key});
  final WaterConfig? initial;
  @override
  WaterEditorState createState() => WaterEditorState();
}

class WaterEditorState extends State<WaterEditor> {
  final controller = AppThemeController.instance;
  late WaterConfig draft = widget.initial ?? controller.waterConfig;
  final _previews = <WidgetSurfaceKind, Uint8List>{};
  Timer? _debounce;
  int _epoch = 0;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.previewWater(draft, owner: this);
        _renderWidgets();
      }
    });
  }

  void _change(Map<String, Object?> v) {
    setState(() => draft = draft.patch(v));
    controller.previewWater(draft, owner: this);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _renderWidgets);
  }

  Future<void> _renderWidgets() async {
    final epoch = ++_epoch, c = draft;
    for (final surface in WidgetSurfaceKind.values) {
      final bytes = await const NativeWidgetPreview().render(
        surface: surface,
        tokens: appThemePalettes[AppThemeId.waterCooling]!.toTokens(),
        configuration: c.widgets,
        themeKey: 'water_cooling',
        waterConfig: c.toJson(),
        fontFamily: c.font.family ?? '',
      );
      if (!mounted || epoch != _epoch) return;
      if (bytes != null) setState(() => _previews[surface] = bytes);
    }
  }

  Future<void> saveAndApply() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (WaterEngine.reservoirProgram == null ||
          WaterEngine.rgbProgram == null) {
        await WaterEngine.warmup();
      }
      await controller.saveWater(draft, apply: true);
      if (!mounted) return;
      controller.previewWater(null, owner: this);
      Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) setState(() => error = 'Không lưu được cấu hình: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _color(int index, {bool coolant = false}) async {
    final original = coolant ? draft.coolant : draft.colors[index];
    var value = original;
    void preview(Color c) {
      value = c;
      if (coolant) {
        _change({'coolant': c.toARGB32()});
      } else {
        final colors = List<Color>.of(draft.colors);
        colors[index] = c;
        _change({'colors': colors.map((c) => c.toARGB32()).toList()});
      }
    }

    final result = await showDialog<Color>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(coolant ? 'Màu nước' : 'Màu LED ${index + 1}'),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: RgbColorBoard(initial: original, onChanged: preview),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, value),
            child: const Text('Chọn'),
          ),
        ],
      ),
    );
    if (result == null) preview(original);
  }

  Future<void> _photo(WidgetSurfaceKind surface) async {
    try {
      final file = await LocalFileBridge.pick(LocalFileKind.image);
      if (file == null || !mounted) return;
      final bytes = await readManagedFile(
        file.path,
        maximumBytes: 30 * 1024 * 1024,
      );
      if (!mounted) return;
      final crop = await Navigator.push<WidgetImageCrop>(
        context,
        MaterialPageRoute(
          builder: (_) => WidgetImageCropEditor(
            bytes: bytes,
            aspectRatio: surface == WidgetSurfaceKind.large
                ? 320 / 150
                : 100 / 134,
          ),
        ),
      );
      if (crop == null || !mounted) return;
      final w = surface == WidgetSurfaceKind.large
          ? draft.widgets.copyWith(
              largeImagePath: file.path,
              largeImageCrop: crop,
            )
          : draft.widgets.copyWith(
              widget2ImagePath: file.path,
              widget2ImageCrop: crop,
            );
      _change({'widgets': w.toJson()});
    } on Object catch (e) {
      if (mounted) setState(() => error = 'Không mở được ảnh: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    ++_epoch;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.previewWater(null, owner: this),
    );
    super.dispose();
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: WaterBlock(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
  Widget _slider(
    String title,
    String key,
    double value, {
    double min = 0,
    double max = 1,
  }) => Row(
    children: [
      SizedBox(
        width: 116,
        child: Text(
          title,
          style: const TextStyle(fontFamily: 'Roboto', fontSize: 12),
        ),
      ),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) => _change({key: v}),
        ),
      ),
      SizedBox(
        width: 34,
        child: Text(
          value.toStringAsFixed(2),
          style: const TextStyle(fontFamily: 'Roboto', fontSize: 10),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final mode = draft.mode,
        multi = [LedMode.wave, LedMode.gradient, LedMode.custom].contains(mode),
        dynamicMode = mode != LedMode.static && mode != LedMode.gradient;
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Roboto'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section('VÒNG TUẦN HOÀN / 01', [
            const Text(
              'KIM LOẠI  /  ACRYLIC  /  NƯỚC',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2,
                color: Color(0xFFC6B4D2),
              ),
            ),
            const SizedBox(height: 12),
            const WaterBlock(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.water_drop_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'WATER COOLING\nPremium',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _change(const WaterConfig().toJson()),
                  child: const Text('Phối màu mặc định'),
                ),
                OutlinedButton(
                  onPressed: () => _change(controller.waterCustom.toJson()),
                  child: const Text('Bản tùy chỉnh đã lưu'),
                ),
              ],
            ),
          ]),
          _section('Bộ điều khiển ARGB', [
            DropdownButtonFormField<LedMode>(
              initialValue: mode,
              key: ValueKey(mode),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chế độ LED'),
              items: [
                for (final m in LedMode.values)
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      switch (m) {
                        LedMode.static => 'Tĩnh',
                        LedMode.rainbow => 'Cầu vồng toàn hệ thống',
                        LedMode.wave => 'Sóng màu',
                        LedMode.beam => 'Dải sáng quét',
                        LedMode.fire => 'Lửa',
                        LedMode.breathing => 'Nhịp thở',
                        LedMode.pulse => 'Xung sáng',
                        LedMode.meteor => 'Sao băng',
                        LedMode.gradient => 'Chuyển sắc',
                        LedMode.custom => 'Phối màu riêng',
                        LedMode.rainbowLine => 'Cầu vồng chạy theo viền',
                      },
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (m) {
                if (m != null) _change({'mode': m.name});
              },
            ),
            if (mode != LedMode.rainbow &&
                mode != LedMode.rainbowLine &&
                mode != LedMode.fire)
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < (multi ? draft.colors.length : 1); i++)
                    IconButton(
                      tooltip: 'Màu LED ${i + 1}',
                      onPressed: () => _color(i),
                      icon: Icon(
                        Icons.circle,
                        color: draft.colors[i],
                        size: 28,
                      ),
                    ),
                  if (multi && draft.colors.length < 4)
                    IconButton(
                      tooltip: 'Thêm màu',
                      onPressed: () => _change({
                        'colors': [
                          ...draft.colors.map((c) => c.toARGB32()),
                          0xFFFF4DAD,
                        ],
                      }),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  if (multi && draft.colors.length > 1)
                    IconButton(
                      tooltip: 'Bớt màu',
                      onPressed: () => _change({
                        'colors': draft.colors
                            .take(draft.colors.length - 1)
                            .map((c) => c.toARGB32())
                            .toList(),
                      }),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                ],
              ),
            _slider('Độ sáng', 'brightness', draft.brightness),
            _slider('Ánh sáng viền', 'glow', draft.glow),
            if (dynamicMode) _slider('Tốc độ', 'speed', draft.speed),
            if (dynamicMode)
              _slider('Cường độ hiệu ứng', 'intensity', draft.intensity),
            if ([
              LedMode.wave,
              LedMode.rainbow,
              LedMode.rainbowLine,
              LedMode.beam,
              LedMode.meteor,
              LedMode.gradient,
              LedMode.custom,
            ].contains(mode))
              _slider(
                'Hướng chuyển động',
                'direction',
                draft.direction,
                max: 360,
              ),
            if (mode == LedMode.wave)
              _slider(
                'Độ rộng sóng',
                'waveWidth',
                draft.waveWidth,
                min: .08,
                max: 2,
              ),
            if (mode == LedMode.beam || mode == LedMode.meteor)
              _slider(
                'Độ rộng vệt sáng',
                'beamWidth',
                draft.beamWidth,
                min: .02,
              ),
          ]),
          _section('Nước & Bể chứa', [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Màu nước'),
              trailing: Icon(Icons.circle, color: draft.coolant),
              onTap: () => _color(0, coolant: true),
            ),
            _slider('Lượng nước', 'fill', draft.fill, min: .08, max: .9),
            _slider('Độ nhớt', 'viscosity', draft.viscosity),
            _slider('Bọt khí', 'bubbles', draft.bubbles),
            _slider('Khúc xạ', 'refraction', draft.refraction),
          ]),
          _section('Phông chữ', [
            DropdownButtonFormField<String>(
              initialValue: draft.font.id,
              key: ValueKey('font:${draft.font.id}'),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Phông chữ có sẵn'),
              items: [
                for (final f in AppFontChoice.builtIns)
                  DropdownMenuItem(
                    value: f.id,
                    child: Text(f.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) {
                if (id != null) _change({'fontId': id});
              },
            ),
          ]),
          _section('Ống dẫn & Vật liệu', [
            _slider(
              'Độ dày ống',
              'tubeWidth',
              draft.tubeWidth,
              min: .8,
              max: 6,
            ),
            _slider('Kim loại', 'metal', draft.metal),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Viền hardline'),
              value: draft.border,
              onChanged: (v) => _change({'border': v}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nước theo chuyển động máy'),
              value: draft.tilt,
              onChanged: (v) => _change({'tilt': v}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Giảm hiệu ứng'),
              value: draft.reduced,
              onChanged: (v) => _change({'reduced': v}),
            ),
          ]),
          _section('Widget', [
            const Text(
              'RGB tĩnh đồng bộ trên màn hình chính. Các chế độ động hoạt động trong app.',
              style: TextStyle(fontSize: 12, color: Color(0xFFC6B4D2)),
            ),
            for (final surface in WidgetSurfaceKind.values) ...[
              const SizedBox(height: 12),
              Text(switch (surface) {
                WidgetSurfaceKind.small => 'Widget nhỏ',
                WidgetSurfaceKind.large => 'Widget lớn',
                WidgetSurfaceKind.widget2 => 'Widget 2',
              }),
              const SizedBox(height: 6),
              if (_previews[surface] != null)
                Image.memory(_previews[surface]!, gaplessPlayback: true)
              else
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Xem trước khả dụng trên Android',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              if (surface != WidgetSurfaceKind.small)
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: () => _photo(surface),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Chọn & căn ảnh'),
                    ),
                    TextButton(
                      onPressed: () => _change({
                        'widgets':
                            (surface == WidgetSurfaceKind.large
                                    ? draft.widgets.copyWith(largeImagePath: '')
                                    : draft.widgets.copyWith(
                                        widget2ImagePath: '',
                                      ))
                                .toJson(),
                      }),
                      child: const Text('Xóa ảnh'),
                    ),
                  ],
                ),
            ],
          ]),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.orange)),
          if (busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
