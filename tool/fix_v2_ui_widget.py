from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"missing marker: {label}")
    return text.replace(old, new, 1)


# Flutter: make the whole visible app rebuild immediately.
app = Path("lib/app/app.dart")
s = app.read_text(encoding="utf-8")
s = replace_once(
    s,
    "class _AppRootState extends State<_AppRoot> {\n  static const _storageKey = 'better_phenikaa_snapshot_v1';\n",
    "class _AppRootState extends State<_AppRoot> {\n  static const _storageKey = 'better_phenikaa_snapshot_v1';\n  final AppThemeController _themes = AppThemeController.instance;\n",
    "app root theme controller",
)
s = replace_once(
    s,
    "  void initState() {\n    super.initState();\n    unawaited(_restore());\n  }\n",
    "  void initState() {\n    super.initState();\n    _themes.addListener(_onThemeChanged);\n    unawaited(_restore());\n  }\n\n  void _onThemeChanged() {\n    if (mounted) {\n      setState(() {});\n    }\n  }\n\n  @override\n  void dispose() {\n    _themes.removeListener(_onThemeChanged);\n    super.dispose();\n  }\n",
    "app root listener",
)
app.write_text(s, encoding="utf-8")

# Theme label/button listens directly too.
theme = Path("lib/theme/app_theme.dart")
t = theme.read_text(encoding="utf-8")
start = t.index("class AppThemeSettingButton extends StatelessWidget")
replacement = r'''class AppThemeSettingButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final palette = controller.palette;
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
                        controller.theme.label,
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
'''
t = t[:start] + replacement
theme.write_text(t, encoding="utf-8")

# Version bump so the new APK is a real update over 2.0.0.
pubspec = Path("pubspec.yaml")
p = pubspec.read_text(encoding="utf-8")
p2 = re.sub(r"^version:\s*2\.0\.0\+5\s*$", "version: 2.0.1+6", p, count=1, flags=re.M)
if p2 == p:
    raise RuntimeError("version marker missing")
pubspec.write_text(p2, encoding="utf-8")

# Theme-specific rounded widget backgrounds. These cover the native StackView's
# perspective margins too, so no classic-blue L shape can leak around themed cards.
drawables = {
    "schedule_widget_background_lol.xml": ("#06131A", "#0B343A"),
    "schedule_widget_background_valorant.xml": ("#0F1923", "#24313B"),
    "schedule_widget_background_minecraft.xml": ("#3A2B20", "#6B4A2F"),
    "schedule_widget_background_facebook.xml": ("#FFFFFF", "#E7F3FF"),
    "schedule_widget_background_shopee.xml": ("#EE4D2D", "#FF6A3D"),
    "schedule_widget_background_tiktok.xml": ("#111111", "#2A1520"),
    "schedule_widget_background_ben10.xml": ("#101510", "#1D5F22"),
    "schedule_widget_background_youtube.xml": ("#181818", "#2B0E14"),
    "schedule_widget_background_steam.xml": ("#171D25", "#1B3D55"),
}
drawable_dir = Path("platform/android_widget/app/src/main/res/drawable")
for name, (start_color, end_color) in drawables.items():
    (drawable_dir / name).write_text(
        f'''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient
        android:angle="0"
        android:startColor="{start_color}"
        android:endColor="{end_color}" />
    <corners android:radius="18dp" />
</shape>
''',
        encoding="utf-8",
    )

# Shrink the peek mask from a full-screen overlay to the tiny corner it actually
# needs to cover, so launcher swipe dispatch remains entirely with StackView.
layout = Path("platform/android_widget/app/src/main/res/layout/schedule_widget.xml")
x = layout.read_text(encoding="utf-8")
old_start = x.index("    <!--\n      StackView intentionally keeps several transformed children")
old_end = x.index('    <ImageView\n        android:id="@+id/widget_calendar"', old_start)
mask = '''    <!-- Only cover the tiny native StackView rear-card peek area. -->
    <ImageView
        android:id="@+id/widget_stack_peek_mask"
        android:layout_width="28dp"
        android:layout_height="24dp"
        android:layout_gravity="bottom|end"
        android:background="@drawable/schedule_widget_stack_peek_mask"
        android:clickable="false"
        android:focusable="false"
        android:importantForAccessibility="no" />

'''
x = x[:old_start] + mask + x[old_end:]
layout.write_text(x, encoding="utf-8")

# Carry over the cross-launcher full-row default span fix from 1.0.
info = Path("platform/android_widget/app/src/main/res/xml/schedule_widget_info.xml")
i = info.read_text(encoding="utf-8")
if 'android:targetCellWidth=' not in i:
    i = replace_once(
        i,
        '    android:resizeMode="horizontal"\n',
        '    android:resizeMode="horizontal"\n    android:targetCellWidth="6"\n',
        "widget target cell width",
    )
info.write_text(i, encoding="utf-8")

# Provider: theme the outer native surface, use a theme-specific adapter identity,
# and do not reset displayed child on every refresh.
provider = Path(
    "platform/android_widget/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/ScheduleWidgetProvider.kt"
)
k = provider.read_text(encoding="utf-8")
k = replace_once(
    k,
    "        val options = appWidgetManager.getAppWidgetOptions(widgetId)\n\n        val views =",
    '''        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val selectionPrefs = context.getSharedPreferences(
            WIDGET_SELECTION_PREFS,
            Context.MODE_PRIVATE,
        )
        val resetPosition = selectionPrefs.getBoolean(resetPositionKey(widgetId), false)

        val views =''',
    "provider reset read",
)
k = k.replace(
    "                        visualHeightDp = size.height,\n                    )",
    "                        visualHeightDp = size.height,\n                        resetPosition = resetPosition,\n                    )",
)
k = k.replace(
    "                    visualHeightDp = fallback.height,\n                )",
    "                    visualHeightDp = fallback.height,\n                    resetPosition = resetPosition,\n                )",
)
k = replace_once(
    k,
    "        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)\n",
    '''        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
        if (resetPosition) {
            selectionPrefs.edit().remove(resetPositionKey(widgetId)).apply()
        }
''',
    "provider reset clear",
)
k = replace_once(
    k,
    "        visualHeightDp: Float,\n    ): RemoteViews {",
    "        visualHeightDp: Float,\n        resetPosition: Boolean,\n    ): RemoteViews {",
    "provider build signature",
)

calendar_padding_marker = '''            views.setViewPadding(
                R.id.widget_calendar,
                calendarPaddingPx,
                calendarPaddingPx,
                calendarPaddingPx,
                calendarPaddingPx,
            )
'''
mask_size = calendar_padding_marker + '''
            views.setViewLayoutWidth(
                R.id.widget_stack_peek_mask,
                (widthDp * STACK_PEEK_MASK_WIDTH_FRACTION).coerceAtLeast(1f),
                TypedValue.COMPLEX_UNIT_DIP,
            )
            views.setViewLayoutHeight(
                R.id.widget_stack_peek_mask,
                (heightDp * STACK_PEEK_MASK_HEIGHT_FRACTION).coerceAtLeast(1f),
                TypedValue.COMPLEX_UNIT_DIP,
            )
'''
k = replace_once(k, calendar_padding_marker, mask_size, "provider mask size")

old_block = '''        val sizeToken = String.format(
            Locale.US,
            "%.1fx%.1f",
            widthDp,
            heightDp,
        )
        val serviceIntent = Intent(context, ScheduleWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(EXTRA_RENDER_WIDTH_DP, renderWidthDp)
            putExtra(EXTRA_RENDER_HEIGHT_DP, renderHeightDp)
            data = Uri.parse("better-phenikaa://widget/$widgetId/$sizeToken")
        }
        val themeKey = context
            .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.appTheme", "classic")
            ?: "classic"
        val themeEndColor = when (themeKey) {
            "lol" -> 0xFF0B343A.toInt()
            "valorant" -> 0xFF24313B.toInt()
            "minecraft" -> 0xFF6B4A2F.toInt()
            "facebook" -> 0xFFE7F3FF.toInt()
            "shopee" -> 0xFFFF6A3D.toInt()
            "tiktok" -> 0xFF2A1520.toInt()
            "ben10" -> 0xFF1D5F22.toInt()
            "youtube" -> 0xFF2B0E14.toInt()
            "steam" -> 0xFF1B3D55.toInt()
            else -> 0xFF315AB5.toInt()
        }
        val iconColor = if (themeKey == "facebook") 0xFF0866FF.toInt() else 0xFFFFFFFF.toInt()
        views.setInt(R.id.widget_stack_peek_mask, "setBackgroundColor", themeEndColor)
        views.setInt(R.id.widget_calendar, "setColorFilter", iconColor)
'''
new_block = '''        val themeKey = context
            .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.appTheme", "classic")
            ?: "classic"
        val themeBackground = when (themeKey) {
            "lol" -> R.drawable.schedule_widget_background_lol
            "valorant" -> R.drawable.schedule_widget_background_valorant
            "minecraft" -> R.drawable.schedule_widget_background_minecraft
            "facebook" -> R.drawable.schedule_widget_background_facebook
            "shopee" -> R.drawable.schedule_widget_background_shopee
            "tiktok" -> R.drawable.schedule_widget_background_tiktok
            "ben10" -> R.drawable.schedule_widget_background_ben10
            "youtube" -> R.drawable.schedule_widget_background_youtube
            "steam" -> R.drawable.schedule_widget_background_steam
            else -> R.drawable.schedule_widget_background
        }
        val themeEndColor = when (themeKey) {
            "lol" -> 0xFF0B343A.toInt()
            "valorant" -> 0xFF24313B.toInt()
            "minecraft" -> 0xFF6B4A2F.toInt()
            "facebook" -> 0xFFE7F3FF.toInt()
            "shopee" -> 0xFFFF6A3D.toInt()
            "tiktok" -> 0xFF2A1520.toInt()
            "ben10" -> 0xFF1D5F22.toInt()
            "youtube" -> 0xFF2B0E14.toInt()
            "steam" -> 0xFF1B3D55.toInt()
            else -> 0xFF315AB5.toInt()
        }
        val themeTextColor = if (themeKey == "facebook") 0xFF050505.toInt() else 0xFFFFFFFF.toInt()
        val iconColor = when (themeKey) {
            "facebook" -> 0xFF0866FF.toInt()
            "lol" -> 0xFFC8AA6E.toInt()
            "tiktok" -> 0xFF25F4EE.toInt()
            "ben10" -> 0xFF7CFF00.toInt()
            "steam" -> 0xFF66C0F4.toInt()
            else -> 0xFFFFFFFF.toInt()
        }
        val sizeToken = String.format(
            Locale.US,
            "%.1fx%.1f",
            widthDp,
            heightDp,
        )
        val serviceIntent = Intent(context, ScheduleWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(EXTRA_RENDER_WIDTH_DP, renderWidthDp)
            putExtra(EXTRA_RENDER_HEIGHT_DP, renderHeightDp)
            data = Uri.parse("better-phenikaa://widget/$widgetId/$sizeToken/$themeKey")
        }
        views.setInt(R.id.widget_root, "setBackgroundResource", themeBackground)
        views.setInt(R.id.widget_stack_peek_mask, "setBackgroundColor", themeEndColor)
        views.setInt(R.id.widget_calendar, "setColorFilter", iconColor)
        views.setTextColor(R.id.widget_empty, themeTextColor)
'''
k = replace_once(k, old_block, new_block, "provider theme block")

k = replace_once(
    k,
    '''        // The selected day (today by default) remains the first item whenever the
        // provider refreshes. Ordinary StackView swipes continue to loop normally.
        views.setDisplayedChild(R.id.widget_list, 0)
        return views
''',
    '''        // Do not force index zero during ordinary theme/data refreshes. Doing so
        // while a launcher is settling a swipe can leave the card visually translated.
        if (resetPosition) {
            views.setDisplayedChild(R.id.widget_list, 0)
        }
        return views
''',
    "provider displayed child reset",
)
k = replace_once(
    k,
    '        fun selectedDateKey(widgetId: Int): String = "selected_date_$widgetId"\n',
    '        fun selectedDateKey(widgetId: Int): String = "selected_date_$widgetId"\n        fun resetPositionKey(widgetId: Int): String = "reset_position_$widgetId"\n',
    "provider reset key",
)
k = replace_once(
    k,
    "        private const val CALENDAR_PADDING_FRACTION = 0.19f\n",
    "        private const val CALENDAR_PADDING_FRACTION = 0.19f\n        private const val STACK_PEEK_MASK_WIDTH_FRACTION = 0.11f\n        private const val STACK_PEEK_MASK_HEIGHT_FRACTION = 0.40f\n",
    "provider mask constants",
)
provider.write_text(k, encoding="utf-8")

# The date picker is the only flow that should force the newly selected date to index 0.
picker = Path(
    "platform/android_widget/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/WidgetDatePickerActivity.kt"
)
d = picker.read_text(encoding="utf-8")
d = replace_once(
    d,
    '''        getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
            MODE_PRIVATE,
        ).edit()
            .putString(ScheduleWidgetProvider.selectedDateKey(widgetId), date)
            .apply()
''',
    '''        getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
            MODE_PRIVATE,
        ).edit()
            .putString(ScheduleWidgetProvider.selectedDateKey(widgetId), date)
            .putBoolean(ScheduleWidgetProvider.resetPositionKey(widgetId), true)
            .apply()
''',
    "date picker reset marker",
)
picker.write_text(d, encoding="utf-8")

# Service: each collection child also receives the chosen theme background. This is
# essential because StackView scales/translates each child independently.
service = Path(
    "platform/android_widget/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/ScheduleWidgetService.kt"
)
q = service.read_text(encoding="utf-8")
q = replace_once(
    q,
    '''        views.setImageViewBitmap(
            R.id.widget_slide_image,
            renderSlide(item),
        )
''',
    '''        val theme = readWidgetTheme(context)
        views.setInt(R.id.widget_slide_item, "setBackgroundResource", theme.backgroundRes)
        views.setImageViewBitmap(
            R.id.widget_slide_image,
            renderSlide(item, theme),
        )
''',
    "service item theme",
)
q = replace_once(
    q,
    "    private fun renderSlide(item: WidgetClass): Bitmap {",
    "    private fun renderSlide(item: WidgetClass, theme: WidgetTheme): Bitmap {",
    "service render signature",
)
q = replace_once(
    q,
    "        val theme = readWidgetTheme(context)\n        val backgroundPaint",
    "        val backgroundPaint",
    "service duplicate theme",
)
q = replace_once(
    q,
    "            textSize = heightPx * SUBJECT_TEXT_HEIGHT_FRACTION\n",
    "            textSize = heightPx * SUBJECT_TEXT_HEIGHT_FRACTION * theme.fontScale\n",
    "service subject font scale",
)
q = replace_once(
    q,
    "            textSize = heightPx * DETAIL_TEXT_HEIGHT_FRACTION\n",
    "            textSize = heightPx * DETAIL_TEXT_HEIGHT_FRACTION * theme.fontScale\n",
    "service detail font scale",
)
q = replace_once(
    q,
    '''            val fitScale = (titleMaxWidth / naturalTitleWidth)
                .coerceAtLeast(MIN_SUBJECT_FIT_SCALE)
''',
    '''            val fitScale = (titleMaxWidth / naturalTitleWidth)
                .coerceAtLeast(theme.minSubjectFitScale)
''',
    "service fit scale",
)

start = q.index("private data class WidgetTheme(")
end = q.index("private fun themedTypeface", start)
themed = r'''private data class WidgetTheme(
    val key: String,
    val startColor: Int,
    val endColor: Int,
    val textColor: Int,
    val subtextColor: Int,
    val backgroundRes: Int,
    val fontScale: Float = 1f,
    val minSubjectFitScale: Float = MIN_SUBJECT_FIT_SCALE,
)

private fun readWidgetTheme(context: Context): WidgetTheme {
    val key = context
        .getSharedPreferences(SNAPSHOT_PREFS, Context.MODE_PRIVATE)
        .getString(THEME_KEY, "classic")
        ?: "classic"
    return when (key) {
        "lol" -> WidgetTheme(key, 0xFF06131A.toInt(), 0xFF0B343A.toInt(), 0xFFF0E6D2.toInt(), 0xFFC8AA6E.toInt(), R.drawable.schedule_widget_background_lol)
        "valorant" -> WidgetTheme(key, 0xFF0F1923.toInt(), 0xFF24313B.toInt(), 0xFFECE8E1.toInt(), 0xFFFF7B86.toInt(), R.drawable.schedule_widget_background_valorant)
        "minecraft" -> WidgetTheme(key, 0xFF3A2B20.toInt(), 0xFF6B4A2F.toInt(), 0xFFFFFFFF.toInt(), 0xFFD8D1C9.toInt(), R.drawable.schedule_widget_background_minecraft, fontScale = 0.84f, minSubjectFitScale = 0.62f)
        "facebook" -> WidgetTheme(key, 0xFFFFFFFF.toInt(), 0xFFE7F3FF.toInt(), 0xFF050505.toInt(), 0xFF65676B.toInt(), R.drawable.schedule_widget_background_facebook)
        "shopee" -> WidgetTheme(key, 0xFFEE4D2D.toInt(), 0xFFFF6A3D.toInt(), 0xFFFFFFFF.toInt(), 0xFFFFE9E1.toInt(), R.drawable.schedule_widget_background_shopee)
        "tiktok" -> WidgetTheme(key, 0xFF111111.toInt(), 0xFF2A1520.toInt(), 0xFFFFFFFF.toInt(), 0xFF25F4EE.toInt(), R.drawable.schedule_widget_background_tiktok)
        "ben10" -> WidgetTheme(key, 0xFF101510.toInt(), 0xFF1D5F22.toInt(), 0xFFFFFFFF.toInt(), 0xFF7CFF00.toInt(), R.drawable.schedule_widget_background_ben10)
        "youtube" -> WidgetTheme(key, 0xFF181818.toInt(), 0xFF2B0E14.toInt(), 0xFFFFFFFF.toInt(), 0xFFFF8A9F.toInt(), R.drawable.schedule_widget_background_youtube)
        "steam" -> WidgetTheme(key, 0xFF171D25.toInt(), 0xFF1B3D55.toInt(), 0xFFD6E9F8.toInt(), 0xFF66C0F4.toInt(), R.drawable.schedule_widget_background_steam)
        else -> WidgetTheme("classic", 0xFF173A8E.toInt(), 0xFF315AB5.toInt(), 0xFFFFFFFF.toInt(), 0xFFDDE8FF.toInt(), R.drawable.schedule_widget_background)
    }
}

'''
q = q[:start] + themed + q[end:]
service.write_text(q, encoding="utf-8")
