from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"missing marker: {label}")
    return text.replace(old, new, 1)


app_path = Path("lib/app/app.dart")
a = app_path.read_text(encoding="utf-8")
a = replace_once(
    a,
    "                  color: palette.accent,\n                  selected: page == _AppPage.exam,",
    "                  color: _panelSecondaryColor(palette),\n                  selected: page == _AppPage.exam,",
    "exam action color",
)
a = replace_once(
    a,
    "                  color: palette.accent,\n                  selected: false,\n                  onTap: () => showAppThemePicker(context),",
    "                  color: _panelTertiaryColor(palette),\n                  selected: false,\n                  onTap: () => showAppThemePicker(context),",
    "theme action color",
)
a = replace_once(
    a,
    """                  child: Icon(\n                    icon,\n                    color:\n                        palette.id == AppThemeId.lol && color == palette.primary\n                        ? const Color(0xFF06171D)\n                        : Colors.white,\n                    size: 20,\n                  ),""",
    """                  child: Icon(\n                    icon,\n                    color: _contrastForeground(color),\n                    size: 20,\n                  ),""",
    "panel icon contrast",
)
helper_marker = "class _MetaLine extends StatelessWidget {"
helpers = r'''Color _panelSecondaryColor(AppThemePalette palette) =>
    Color.lerp(palette.primary, palette.accent, .34) ?? palette.primary;

Color _panelTertiaryColor(AppThemePalette palette) =>
    Color.lerp(palette.primary, palette.accent, .68) ?? palette.primary;

Color _contrastForeground(Color background) =>
    background.computeLuminance() > .52
    ? const Color(0xFF151515)
    : Colors.white;

'''
if helpers not in a:
    a = replace_once(a, helper_marker, helpers + helper_marker, "panel helpers")
app_path.write_text(a, encoding="utf-8")


service_path = Path(
    "platform/android_widget/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/ScheduleWidgetService.kt"
)
s = service_path.read_text(encoding="utf-8")
canvas_marker = """        val canvas = Canvas(horizontal)\n        val widthPx = width.toFloat()\n        val heightPx = height.toFloat()\n\n        // Every coordinate is proportional to the real frame supplied by the host."""
canvas_replacement = """        val canvas = Canvas(horizontal)\n        val widthPx = width.toFloat()\n        val heightPx = height.toFloat()\n        val theme = readWidgetTheme(context)\n\n        // StackView keeps neighbouring children alive. Every child must be opaque;\n        // transparent text-only children can all become visible together after a\n        // Samsung Launcher refresh/restore and create the overlapping-text defect.\n        val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {\n            shader = LinearGradient(\n                0f,\n                0f,\n                widthPx,\n                0f,\n                theme.startColor,\n                theme.endColor,\n                Shader.TileMode.CLAMP,\n            )\n        }\n        canvas.drawRect(0f, 0f, widthPx, heightPx, backgroundPaint)\n\n        // Every coordinate is proportional to the real frame supplied by the host."""
s = replace_once(s, canvas_marker, canvas_replacement, "opaque item background")
s = replace_once(
    s,
    """        // Theme-independent transparent collection layer. The native themed\n        // background below StackView changes atomically, so switching themes never\n        // invalidates/rebuilds the collection on Samsung Launcher.\n        val subjectPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {\n            color = 0xFFFFFFFF.toInt()\n            textSize = heightPx * SUBJECT_TEXT_HEIGHT_FRACTION\n            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)""",
    """        val subjectPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {\n            color = theme.textColor\n            textSize = heightPx * SUBJECT_TEXT_HEIGHT_FRACTION\n            typeface = themedTypeface(context, theme, Typeface.BOLD)""",
    "subject theme paint",
)
s = replace_once(
    s,
    """        val detailPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {\n            color = 0xFFE4EBF3.toInt()\n            textSize = heightPx * DETAIL_TEXT_HEIGHT_FRACTION\n            typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)""",
    """        val detailPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {\n            color = theme.subtextColor\n            textSize = heightPx * DETAIL_TEXT_HEIGHT_FRACTION\n            typeface = themedTypeface(context, theme, Typeface.NORMAL)""",
    "detail theme paint",
)
service_path.write_text(s, encoding="utf-8")


provider_path = Path(
    "platform/android_widget/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/ScheduleWidgetProvider.kt"
)
p = provider_path.read_text(encoding="utf-8")
p = replace_once(
    p,
    """        val contentToken = collectionContentToken(context, widgetId, options)\n        val previousToken = renderStatePrefs.getString(contentTokenKey(widgetId), null)\n        val collectionChanged = previousToken != contentToken\n""",
    """        val contentToken = collectionContentToken(context, widgetId, options)\n        val previousToken = renderStatePrefs.getString(contentTokenKey(widgetId), null)\n        val collectionChanged = previousToken != contentToken\n        val themeKey = readThemeColors(context).key\n        val previousThemeKey = renderStatePrefs.getString(themeTokenKey(widgetId), null)\n        val themeChanged = previousThemeKey != themeKey\n""",
    "theme change tracking",
)
p = replace_once(
    p,
    """        if (collectionChanged) {\n            appWidgetManager.updateAppWidget(widgetId, views)\n            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)\n            renderStatePrefs.edit().putString(contentTokenKey(widgetId), contentToken).apply()\n        } else {\n            // Theme-only path: update background/calendar chrome without touching\n            // StackView or its adapter. No old/new collection frames can overlap.\n            appWidgetManager.partiallyUpdateAppWidget(widgetId, views)\n        }\n""",
    """        if (collectionChanged) {\n            appWidgetManager.updateAppWidget(widgetId, views)\n            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)\n            renderStatePrefs.edit()\n                .putString(contentTokenKey(widgetId), contentToken)\n                .putString(themeTokenKey(widgetId), themeKey)\n                .apply()\n        } else if (themeChanged) {\n            // Keep the adapter identity stable. Repaint its existing children in place;\n            // their opaque backgrounds prevent any neighbouring item from showing\n            // through during the refresh.\n            appWidgetManager.partiallyUpdateAppWidget(widgetId, views)\n            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)\n            renderStatePrefs.edit().putString(themeTokenKey(widgetId), themeKey).apply()\n        } else {\n            appWidgetManager.partiallyUpdateAppWidget(widgetId, views)\n        }\n""",
    "stable theme refresh path",
)
p = replace_once(
    p,
    """    private fun contentTokenKey(widgetId: Int): String = \"content_token_$widgetId\"\n""",
    """    private fun contentTokenKey(widgetId: Int): String = \"content_token_$widgetId\"\n\n    private fun themeTokenKey(widgetId: Int): String = \"theme_token_$widgetId\"\n""",
    "theme token helper",
)
provider_path.write_text(p, encoding="utf-8")


pubspec_path = Path("pubspec.yaml")
ps = pubspec_path.read_text(encoding="utf-8")
ps2 = re.sub(r"^version:\s*2\.0\.\d+\+\d+\s*$", "version: 2.0.6+11", ps, count=1, flags=re.M)
if ps2 == ps:
    raise RuntimeError("version marker missing")
pubspec_path.write_text(ps2, encoding="utf-8")
