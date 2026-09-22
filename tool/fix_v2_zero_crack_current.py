from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"missing marker: {label}")
    return text.replace(old, new, 1)


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
if old_bg in s:
    s = s.replace(old_bg, "", 1)

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
new_paints = '''        // Theme-independent transparent collection layer. The native themed
        // background below StackView changes atomically, so switching themes never
        // invalidates/rebuilds the collection on Samsung Launcher.
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
if old_paints in s:
    s = s.replace(old_paints, new_paints, 1)
elif "Theme-independent transparent collection layer" not in s:
    raise RuntimeError("missing marker: theme-neutral content paints")
service_path.write_text(s, encoding="utf-8")


provider_path = Path(
    "platform/android_widget/app/src/main/kotlin/vn/edu/phenikaa/better_phenikaa_schedule/ScheduleWidgetProvider.kt"
)
p = provider_path.read_text(encoding="utf-8")

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
            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
            renderStatePrefs.edit().putString(contentTokenKey(widgetId), contentToken).apply()
        } else {
            // Theme-only path: update background/calendar chrome without touching
            // StackView or its adapter. No old/new collection frames can overlap.
            appWidgetManager.partiallyUpdateAppWidget(widgetId, views)
        }
    }

'''
pattern = re.compile(
    r"    private fun renderWidget\(.*?\n    private fun buildWidgetViews\(",
    re.S,
)
match = pattern.search(p)
if not match:
    raise RuntimeError("missing marker: renderWidget block")
p = p[: match.start()] + new_render + "    private fun buildWidgetViews(" + p[match.end() :]

old_signature_tail = '''
        context: Context,
        widgetId: Int,
        visualWidthDp: Float,
        visualHeightDp: Float,
    ): RemoteViews {
'''
new_signature_tail = '''
        context: Context,
        widgetId: Int,
        visualWidthDp: Float,
        visualHeightDp: Float,
        bindCollection: Boolean,
    ): RemoteViews {
'''
if old_signature_tail in p:
    p = p.replace(old_signature_tail, new_signature_tail, 1)
elif "bindCollection: Boolean" not in p:
    raise RuntimeError("missing marker: buildWidgetViews signature")

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
if old_adapter in p:
    p = p.replace(old_adapter, new_adapter, 1)
elif "if (bindCollection) {\n            val sizeToken" not in p:
    raise RuntimeError("missing marker: collection binding block")

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
if old_reset in p:
    p = p.replace(old_reset, new_reset, 1)
elif "if (bindCollection) {\n            val selectionPrefs" not in p:
    raise RuntimeError("missing marker: collection reset block")

facebook_old = '            "facebook" -> ThemeColors(key, 0xFFFFFFFF.toInt(), 0xFFE7F3FF.toInt(), 0xFF050505.toInt(), 0xFF0866FF.toInt())\n'
facebook_new = '            "facebook" -> ThemeColors(key, 0xFF1877F2.toInt(), 0xFF0866FF.toInt(), 0xFFFFFFFF.toInt(), 0xFFFFFFFF.toInt())\n'
if facebook_old in p:
    p = p.replace(facebook_old, facebook_new, 1)

helper_marker = '''    @Suppress("DEPRECATION")
    private fun exactWidgetSizes(options: Bundle): List<SizeF> {
'''
if "private fun collectionContentToken(" not in p:
    helper = '''    private fun collectionContentToken(
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
    if helper_marker not in p:
        raise RuntimeError("missing marker: token helper")
    p = p.replace(helper_marker, helper + helper_marker, 1)

if "WIDGET_RENDER_STATE_PREFS" not in p:
    p = p.replace(
        '        const val WIDGET_SELECTION_PREFS = "better_phenikaa_widget_selection"\n',
        '        const val WIDGET_SELECTION_PREFS = "better_phenikaa_widget_selection"\n        private const val WIDGET_RENDER_STATE_PREFS = "better_phenikaa_widget_render_state"\n',
        1,
    )
provider_path.write_text(p, encoding="utf-8")


# The peek mask is no longer needed because StackView items are transparent.
# Keeping it hidden also removes the last possible colored sliver below calendar.
layout_path = Path("platform/android_widget/app/src/main/res/layout/schedule_widget.xml")
x = layout_path.read_text(encoding="utf-8")
mask_marker = '''    <ImageView
        android:id="@+id/widget_stack_peek_mask"
        android:layout_width="40dp"
        android:layout_height="26dp"
        android:layout_gravity="bottom|end"
        android:clickable="false"
        android:contentDescription="@null"
        android:focusable="false" />
'''
mask_hidden = '''    <ImageView
        android:id="@+id/widget_stack_peek_mask"
        android:layout_width="1dp"
        android:layout_height="1dp"
        android:layout_gravity="bottom|end"
        android:clickable="false"
        android:contentDescription="@null"
        android:focusable="false"
        android:visibility="gone" />
'''
if mask_marker in x:
    x = x.replace(mask_marker, mask_hidden, 1)
layout_path.write_text(x, encoding="utf-8")
