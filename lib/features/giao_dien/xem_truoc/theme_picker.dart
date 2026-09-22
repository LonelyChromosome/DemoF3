import 'package:better_phenikaa_schedule/features/giao_dien/bo_may/theme_source.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/du_lieu/custom_theme.dart';
import 'package:better_phenikaa_schedule/features/giao_dien/xem_truoc/custom_theme_editor.dart';
import 'package:better_phenikaa_schedule/theme/app_theme.dart';
import 'package:flutter/material.dart';

const _presetIds = <AppThemeId>[
  AppThemeId.classic,
  AppThemeId.lol,
  AppThemeId.valorant,
  AppThemeId.minecraft,
  AppThemeId.facebook,
  AppThemeId.shopee,
  AppThemeId.tiktok,
  AppThemeId.ben10,
  AppThemeId.youtube,
  AppThemeId.steam,
];

Future<void> showAppThemePicker(BuildContext context) async {
  final controller = AppThemeController.instance;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99000000),
    builder: (context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _ThemePickerSheet(controller: controller),
    ),
  );
}

class _ThemePickerSheet extends StatelessWidget {
  const new({required this.controller});

  final AppThemeController controller;

  @override
  Widget build(BuildContext context) {
    final palette = controller.palette;
    final radius = palette.geometry == AppThemeGeometry.rounded ? 28.0 : 0.0;
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.86,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: palette.shadow,
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: palette.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              'Giao diện',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: themeLetterSpacing(palette),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Preset cũ được giữ nguyên. Theme mới chỉ áp dụng sau khi bạn xác nhận.',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const CustomThemeEditor(),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Tạo theme từ ảnh hoặc phối màu'),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: <Widget>[
                  SliverToBoxAdapter(child: _heading('Preset có sẵn', palette)),
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 9, bottom: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.45,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _PresetCard(
                          id: _presetIds[index],
                          selected: controller.theme == _presetIds[index],
                          onTap: () => controller.select(_presetIds[index]),
                        ),
                        childCount: _presetIds.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _heading(
                      'Theme đã lưu (${controller.customThemes.length})',
                      palette,
                    ),
                  ),
                  if (controller.customThemes.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'Chưa có theme tùy chỉnh.',
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final theme = controller.customThemes[index];
                        return _CustomThemeCard(
                          theme: theme,
                          selected:
                              controller.activeCustomTheme?.id == theme.id,
                          onApply: () => controller.applyCustomTheme(theme),
                          onEdit: () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  CustomThemeEditor(existing: theme),
                            ),
                          ),
                          onDelete: () => _confirmDelete(context, theme),
                        );
                      }, childCount: controller.customThemes.length),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String label, AppThemePalette palette) => Text(
    label,
    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
  );

  Future<void> _confirmDelete(
    BuildContext context,
    CustomThemeDefinition theme,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa theme?'),
        content: Text('“${theme.name}” sẽ bị xóa khỏi thiết bị.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteCustomTheme(theme.id);
  }
}

class _PresetCard extends StatelessWidget {
  const new({required this.id, required this.selected, required this.onTap});

  final AppThemeId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = appThemePalette;
    final preview = appThemePalettes[id]!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active.card,
          borderRadius: BorderRadius.circular(
            active.geometry == AppThemeGeometry.rounded ? 14 : 2,
          ),
          border: Border.all(
            color: selected ? active.primary : active.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      preview.pageStart,
                      preview.primary,
                      preview.accent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    preview.geometry == AppThemeGeometry.rounded ? 9 : 1,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      selected ? Icons.check_circle_rounded : id.icon,
                      color: preview.widgetText,
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              id.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
            Text(
              id.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: active.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomThemeCard extends StatelessWidget {
  const new({
    required this.theme,
    required this.selected,
    required this.onApply,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomThemeDefinition theme;
  final bool selected;
  final VoidCallback onApply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final active = appThemePalette;
    final tokens = theme.tokens;
    return Card(
      margin: const EdgeInsets.only(top: 9),
      child: ListTile(
        onTap: onApply,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[tokens.primary, tokens.accent],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? active.primary : active.border,
              width: 2,
            ),
          ),
          child: selected
              ? Icon(Icons.check_rounded, color: tokens.widgetText)
              : null,
        ),
        title: Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${theme.source.kind == ThemeSourceKind.image ? 'Ảnh' : 'Phối màu'} • ${theme.font.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
            PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ),
      ),
    );
  }
}

class AppThemeSettingButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final palette = controller.palette;
        final label =
            controller.activeCustomTheme?.name ?? controller.theme.label;
        return AppThemePanel(
          elevated: false,
          alt: true,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: InkWell(
            onTap: () => showAppThemePicker(context),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[palette.primary, palette.accent],
                    ),
                    borderRadius: BorderRadius.circular(
                      palette.geometry == AppThemeGeometry.rounded ? 10 : 1,
                    ),
                  ),
                  child: Icon(
                    controller.theme.icon,
                    color: palette.widgetText,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Giao diện',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}
