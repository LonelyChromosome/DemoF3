from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"missing marker: {label}")
    return text.replace(old, new, 1)


# -----------------------------------------------------------------------------
# Widget item: make collection content theme-neutral and transparent.
# Theme changes can then update only the native background without invalidating
# StackView's collection, which avoids Samsung Launcher's torn transition.
# -----------------------------------------------------------------------------
service_path = Path(
    "platform/android_widget/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/ScheduleWidgetService.kt"
)
s = service_path.read_text(encoding="utf-8")

old_bg = '''        val theme = readWidgetTheme(context)
        val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f,
                0f,
                widthPx,
                0f,
                theme.startColor,
                theme.endColor,
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 0f, widthPx, heightPx, backgroundPaint)

'''
s = replace_once(s, old_bg, "", "opaque slide theme background")

old_paints = '''        val subjectPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = theme.textColor
            textSize = heightPx * SUBJECT_TEXT_HEIGHT_FRACTION * if (theme.key == "minecraft") 0.86f else 1f
            typeface = themedTypeface(context, theme, Typeface.BOLD)
        }
        val detailPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = theme.subtextColor
            textSize = heightPx * DETAIL_TEXT_HEIGHT_FRACTION * if (theme.key == "minecraft") 0.84f else 1f
            typeface = themedTypeface(context, theme, Typeface.NORMAL)
        }
'''
new_paints = '''        // Keep collection items independent from the active theme. The themed card
        // itself is rendered by ScheduleWidgetProvider underneath this transparent
        // bitmap. A theme switch therefore never invalidates/rebuilds StackView.
        val subjectPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            textSize = heightPx * SUBJECT_TEXT_HEIGHT_FRACTION
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            setShadowLayer(heightPx * 0.018f, 0f, heightPx * 0.008f, 0x66000000)
        }
        val detailPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFE4EBF3.toInt()
            textSize = heightPx * DETAIL_TEXT_HEIGHT_FRACTION
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            setShadowLayer(heightPx * 0.015f, 0f, heightPx * 0.006f, 0x66000000)
        }
'''
s = replace_once(s, old_paints, new_paints, "theme-neutral content paints")
service_path.write_text(s, encoding="utf-8")


# -----------------------------------------------------------------------------
# Provider: update theme chrome with partiallyUpdateAppWidget. Only invalidate
# the StackView collection when its actual content/date/size changes.
# -----------------------------------------------------------------------------
provider_path = Path(
    "platform/android_widget/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/ScheduleWidgetProvider.kt"
)
p = provider_path.read_text(encoding="utf-8")

old_render = '''    private fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)

        val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val exactSizes = exactWidgetSizes(options)
            if (exactSizes.isNotEmpty()) {
                val sizedViews = LinkedHashMap<SizeF, RemoteViews>()
                exactSizes.take(MAX_EXACT_LAYOUTS).forEach { size ->
                    sizedViews[size] = buildWidgetViews(
                        context = context,
                        widgetId = widgetId,
                        visualWidthDp = size.width,
                        visualHeightDp = size.height,
                    )
                }
                RemoteViews(sizedViews)
            } else {
                val fallback = legacyWidgetSize(options)
                buildWidgetViews(
                    context = context,
                    widgetId = widgetId,
                    visualWidthDp = fallback.width,
                    visualHeightDp = fallback.height,
                )
            }
        } else {
            val fallback = legacyWidgetSize(options)
            buildWidgetViews(
                context = context,
                widgetId = widgetId,
                visualWidthDp = fallback.width,
                visualHeightDp = fallback.height,
            )
        }

        // Refresh the existing collection factory before applying the small
        // native chrome update. With a stable adapter URI this updates the visible
        // card in-place instead of showing a torn old/new theme frame.
        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
        appWidgetManager.updateAppWidget(widgetId, views)
    }
'''
new_render = '''    private fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val renderStatePrefs = context.getSharedPreferences(
            WIDGET_RENDER_STATE_PREFS,
            Context.MODE_PRIVATE,
        )
        val contentToken = collectionContentToken(context, widgetId, options)
        val previousToken = renderStatePrefs.getString(contentTokenKey(widgetId), null)
        val collectionChanged = previousToken != contentToken

        val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val exactSizes = exactWidgetSizes(options)
            if (exactSizes.isNotEmpty()) {
                val sizedViews = LinkedHashMap<SizeF, RemoteViews>()
                exactSizes.take(MAX_EXACT_LAYOUTS).forEach { size ->
                    sizedViews[size] = buildWidgetViews(
                        context = context,
                        widgetId = widgetId,
                        visualWidthDp = size.width,
                        visualHeightDp = size.height,
                        bindCollection = collectionChanged,
                    )
                }
                RemoteViews(sizedViews)
            } else {
                val fallback = legacyWidgetSize(options)
                buildWidgetViews(
                    context = context,
                    widgetId = widgetId,
                    visualWidthDp = fallback.width,
                    visualHeightDp = fallback.height,
                    bindCollection = collectionChanged,
                )
            }
        } else {
            val fallback = legacyWidgetSize(options)
            buildWidgetViews(
                context = context,
                widgetId = widgetId,
                visualWidthDp = fallback.width,
                visualHeightDp = fallback.height,
                bindCollection = collectionChanged,
            )
        }

        if (collectionChanged) {
            // First render, data/date change or resize: install the full widget and
            // then refresh collection rows. Theme-only changes never enter here.
            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
            renderStatePrefs.edit().putString(contentTokenKey(widgetId), contentToken).apply()
        } else {
            // Theme-only path. Do not touch setRemoteAdapter/StackView at all.
            // Samsung Launcher can apply this native background/icon update as one
            // frame instead of animating a newly-invalidated collection.
            appWidgetManager.partiallyUpdateAppWidget(widgetId, views)
        }
    }
'''
p = replace_once(p, old_render, new_render, "renderWidget partial theme path")

old_signature = '''    private fun buildWidgetViews(
        context: Context,
        widgetId: Int,
        visualWidthDp: Float,
        visualHeightDp: Float,
    ): RemoteViews {
'''
new_signature = '''    private fun buildWidgetViews(
        context: Context,
        widgetId: Int,
        visualWidthDp: Float,
        visualHeightDp: Float,
        bindCollection: Boolean,
    ): RemoteViews {
'''
p = replace_once(p, old_signature, new_signature, "buildWidgetViews bindCollection")

old_adapter = '''        val sizeToken = String.format(
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
        views.setRemoteAdapter(R.id.widget_list, serviceIntent)
        views.setEmptyView(R.id.widget_list, R.id.widget_empty)

        context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launchIntent ->
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val openApp = PendingIntent.getActivity(
                context,
                widgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            views.setPendingIntentTemplate(R.id.widget_list, openApp)
            views.setOnClickPendingIntent(R.id.widget_empty, openApp)
        }
'''
new_adapter = '''        if (bindCollection) {
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
                data = Uri.parse("better-phenikaa://widget/$widgetId/$sizeToken")
            }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launchIntent ->
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                val openApp = PendingIntent.getActivity(
                    context,
                    widgetId,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
                )
                views.setPendingIntentTemplate(R.id.widget_list, openApp)
                views.setOnClickPendingIntent(R.id.widget_empty, openApp)
            }
        }
'''
p = replace_once(p, old_adapter, new_adapter, "skip adapter binding on theme-only update")

# Never mutate displayed child during a partial theme update.
old_reset = '''        val selectionPrefs = context.getSharedPreferences(
            WIDGET_SELECTION_PREFS,
            Context.MODE_PRIVATE,
        )
        if (selectionPrefs.getBoolean(resetChildKey(widgetId), false)) {
            views.setDisplayedChild(R.id.widget_list, 0)
            selectionPrefs.edit().remove(resetChildKey(widgetId)).apply()
        }
'''
new_reset = '''        if (bindCollection) {
            val selectionPrefs = context.getSharedPreferences(
                WIDGET_SELECTION_PREFS,
                Context.MODE_PRIVATE,
            )
            if (selectionPrefs.getBoolean(resetChildKey(widgetId), false)) {
                views.setDisplayedChild(R.id.widget_list, 0)
                selectionPrefs.edit().remove(resetChildKey(widgetId)).apply()
            }
        }
'''
p = replace_once(p, old_reset, new_reset, "theme update must preserve displayed child")

# Facebook must use a saturated widget surface now that StackView content uses
# stable white text independent of theme.
p = replace_once(
    p,
    '            "facebook" -> ThemeColors(key, 0xFFFFFFFF.toInt(), 0xFFE7F3FF.toInt(), 0xFF050505.toInt(), 0xFF0866FF.toInt())\n',
    '            "facebook" -> ThemeColors(key, 0xFF1877F2.toInt(), 0xFF0866FF.toInt(), 0xFFFFFFFF.toInt(), 0xFFFFFFFF.toInt())\n',
    "facebook widget contrast",
)

# Add a collection token that deliberately excludes theme. Theme updates then go
# through partiallyUpdateAppWidget and never invalidate StackView.
insert_before = '''    @Suppress("DEPRECATION")
    private fun exactWidgetSizes(options: Bundle): List<SizeF> {
'''
helpers = '''    private fun collectionContentToken(
        context: Context,
        widgetId: Int,
        options: Bundle,
    ): String {
        val snapshot = context
            .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.better_phenikaa_snapshot_v1", "")
            .orEmpty()
        val selectedDate = context
            .getSharedPreferences(WIDGET_SELECTION_PREFS, Context.MODE_PRIVATE)
            .getString(selectedDateKey(widgetId), "")
            .orEmpty()
        val sizeSignature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            exactWidgetSizes(options).joinToString(";") { size ->
                String.format(Locale.US, "%.1fx%.1f", size.width, size.height)
            }
        } else {
            val size = legacyWidgetSize(options)
            String.format(Locale.US, "%.1fx%.1f", size.width, size.height)
        }
        return "${snapshot.hashCode()}|$selectedDate|$sizeSignature"
    }

    private fun contentTokenKey(widgetId: Int): String = "content_token_$widgetId"

'''
if insert_before not in p:
    raise RuntimeError("missing marker: content token helper insertion")
p = p.replace(insert_before, helpers + insert_before, 1)

p = p.replace(
    '        const val WIDGET_SELECTION_PREFS = "better_phenikaa_widget_selection"\n',
    '        const val WIDGET_SELECTION_PREFS = "better_phenikaa_widget_selection"\n        private const val WIDGET_RENDER_STATE_PREFS = "better_phenikaa_widget_render_state"\n',
    1,
)
provider_path.write_text(p, encoding="utf-8")


# Version bump.
pubspec_path = Path("pubspec.yaml")
v = pubspec_path.read_text(encoding="utf-8")
v2 = re.sub(r"^version:\s*2\.0\.3\+8\s*$", "version: 2.0.4+9", v, count=1, flags=re.M)
if v2 == v:
    # Allow rerun after a previous successful source commit.
    if "version: 2.0.4+9" not in v:
        raise RuntimeError("version marker missing")
else:
    pubspec_path.write_text(v2, encoding="utf-8")
