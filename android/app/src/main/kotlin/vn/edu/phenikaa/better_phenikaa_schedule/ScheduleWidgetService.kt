package vn.edu.phenikaa.better_phenikaa_schedule

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Build
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ScheduleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        ScheduleWidgetFactory(
            applicationContext,
            intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            ),
            intent.getIntExtra(
                ScheduleWidgetProvider.EXTRA_RENDER_WIDTH_DP,
                DEFAULT_WIDGET_WIDTH_DP,
            ),
            intent.getIntExtra(
                ScheduleWidgetProvider.EXTRA_RENDER_HEIGHT_DP,
                DEFAULT_WIDGET_HEIGHT_DP,
            ),
        )
}

private class ScheduleWidgetFactory(
    private val context: Context,
    private val widgetId: Int,
    private val renderWidthDp: Int,
    private val renderHeightDp: Int,
) : RemoteViewsService.RemoteViewsFactory {
    private var items: List<WidgetClass> = emptyList()

    override fun onCreate() {
        reload()
    }

    override fun onDataSetChanged() {
        reload()
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_item)
        val item = items.getOrNull(position) ?: return views
        val widthDp = renderWidthDp.coerceAtLeast(1)
        val heightDp = renderHeightDp.coerceAtLeast(1)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutWidth(
                R.id.widget_slide_item,
                widthDp.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP,
            )
            views.setViewLayoutHeight(
                R.id.widget_slide_item,
                heightDp.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP,
            )
        }

        views.setImageViewBitmap(
            R.id.widget_slide_image,
            renderSlide(item),
        )
        views.setOnClickFillInIntent(
            R.id.widget_slide_item,
            Intent().apply {
                putExtra("scheduleRecordId", item.id)
            },
        )
        return views
    }

    override fun getLoadingView(): RemoteViews? {
        val item = items.firstOrNull() ?: return null
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_item)
        val widthDp = renderWidthDp.coerceAtLeast(1)
        val heightDp = renderHeightDp.coerceAtLeast(1)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutWidth(
                R.id.widget_slide_item,
                widthDp.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP,
            )
            views.setViewLayoutHeight(
                R.id.widget_slide_item,
                heightDp.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP,
            )
        }
        views.setImageViewBitmap(R.id.widget_slide_image, renderSlide(item))
        return views
    }

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long =
        items.getOrNull(position)?.stableId ?: position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun reload() {
        items = readWidgetClasses(context, widgetId)
    }

    private fun renderSlide(item: WidgetClass): Bitmap =
        renderWidgetSlide(context, item, renderWidthDp, renderHeightDp)

}


private fun renderWidgetSlide(
    context: Context,
    item: WidgetClass,
    renderWidthDp: Int,
    renderHeightDp: Int,
): Bitmap {
        val density = context.resources.displayMetrics.density
        val widthDp = renderWidthDp.coerceAtLeast(1)
        val heightDp = renderHeightDp.coerceAtLeast(1)
        val width = (widthDp * density).toInt().coerceAtLeast(1)
        val height = (heightDp * density).toInt().coerceAtLeast(1)
        val horizontal = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(horizontal)
        val widthPx = width.toFloat()
        val heightPx = height.toFloat()
        val theme = readWidgetTheme(context)

        // StackView keeps neighbouring children alive. Every child must be opaque;
        // transparent text-only children can all become visible together after a
        // Samsung Launcher refresh/restore and create the overlapping-text defect.
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

        // Every coordinate is proportional to the real frame supplied by the host.
        // Keep the visual spacing from the approved layout while leaving the far
        // lower-right edge clear for the StackView peek mask in schedule_widget.xml.
        val left = widthPx * CONTENT_LEFT_FRACTION
        val titleRight = widthPx * TITLE_RIGHT_FRACTION
        val detailRight = widthPx * DETAIL_RIGHT_FRACTION

        val subjectPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = theme.textColor
            textSize = heightPx * SUBJECT_TEXT_HEIGHT_FRACTION
            typeface = themedTypeface(context, theme, Typeface.BOLD)
            setShadowLayer(heightPx * 0.018f, 0f, heightPx * 0.008f, 0x66000000)
        }
        val detailPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = theme.subtextColor
            textSize = heightPx * DETAIL_TEXT_HEIGHT_FRACTION
            typeface = themedTypeface(context, theme, Typeface.NORMAL)
            setShadowLayer(heightPx * 0.015f, 0f, heightPx * 0.006f, 0x66000000)
        }

        val titleMaxWidth = (titleRight - left).coerceAtLeast(
            widthPx * MIN_TITLE_WIDTH_FRACTION,
        )
        val naturalTitleWidth = subjectPaint.measureText(item.subject)
        if (naturalTitleWidth > titleMaxWidth && naturalTitleWidth > 0f) {
            val fitScale = (titleMaxWidth / naturalTitleWidth)
                .coerceAtLeast(MIN_SUBJECT_FIT_SCALE)
            subjectPaint.textSize *= fitScale
        }
        val subject = TextUtils.ellipsize(
            item.subject,
            subjectPaint,
            titleMaxWidth,
            TextUtils.TruncateAt.END,
        )
        canvas.drawText(
            subject.toString(),
            left,
            heightPx * SUBJECT_BASELINE_HEIGHT_FRACTION,
            subjectPaint,
        )

        var timeWidth = detailPaint.measureText(item.time)
        val availableDetailWidth = (detailRight - left).coerceAtLeast(1f)
        val minRoomWidth = widthPx * MIN_DETAIL_WIDTH_FRACTION
        val detailGap = widthPx * DETAIL_GAP_WIDTH_FRACTION
        if (item.time.isNotBlank() && timeWidth + minRoomWidth + detailGap > availableDetailWidth) {
            val fitScale = ((availableDetailWidth - minRoomWidth - detailGap) / timeWidth)
                .coerceIn(MIN_DETAIL_FIT_SCALE, 1f)
            detailPaint.textSize *= fitScale
            timeWidth = detailPaint.measureText(item.time)
        }
        val roomMaxWidth = (
            detailRight - left - timeWidth - detailGap
        ).coerceAtLeast(minRoomWidth)
        val room = TextUtils.ellipsize(
            item.room,
            detailPaint,
            roomMaxWidth,
            TextUtils.TruncateAt.END,
        )
        canvas.drawText(
            room.toString(),
            left,
            heightPx * DETAIL_BASELINE_HEIGHT_FRACTION,
            detailPaint,
        )
        if (item.time.isNotBlank()) {
            canvas.drawText(
                item.time,
                detailRight - timeWidth,
                heightPx * DETAIL_BASELINE_HEIGHT_FRACTION,
                detailPaint,
            )
        }

        return horizontal
    
}

internal fun renderWidgetRefreshCover(
    context: Context,
    widgetId: Int,
    renderWidthDp: Int,
    renderHeightDp: Int,
): Bitmap? {
    val first = readWidgetClasses(context, widgetId).firstOrNull() ?: return null
    return renderWidgetSlide(context, first, renderWidthDp, renderHeightDp)
}

private data class WidgetTheme(
    val key: String,
    val startColor: Int,
    val endColor: Int,
    val textColor: Int,
    val subtextColor: Int,
)

private fun readWidgetTheme(context: Context): WidgetTheme {
    val key = context
        .getSharedPreferences(SNAPSHOT_PREFS, Context.MODE_PRIVATE)
        .getString(THEME_KEY, "classic")
        ?: "classic"
    return when (key) {
        "lol" -> WidgetTheme(key, 0xFF06131A.toInt(), 0xFF0B343A.toInt(), 0xFFF0E6D2.toInt(), 0xFFC8AA6E.toInt())
        "valorant" -> WidgetTheme(key, 0xFF0F1923.toInt(), 0xFF24313B.toInt(), 0xFFECE8E1.toInt(), 0xFFFF7B86.toInt())
        "minecraft" -> WidgetTheme(key, 0xFF3A2B20.toInt(), 0xFF6B4A2F.toInt(), 0xFFFFFFFF.toInt(), 0xFFD8D1C9.toInt())
        "facebook" -> WidgetTheme(key, 0xFFFFFFFF.toInt(), 0xFFE7F3FF.toInt(), 0xFF050505.toInt(), 0xFF65676B.toInt())
        "shopee" -> WidgetTheme(key, 0xFFEE4D2D.toInt(), 0xFFFF6A3D.toInt(), 0xFFFFFFFF.toInt(), 0xFFFFE9E1.toInt())
        "tiktok" -> WidgetTheme(key, 0xFF111111.toInt(), 0xFF2A1520.toInt(), 0xFFFFFFFF.toInt(), 0xFF25F4EE.toInt())
        "ben10" -> WidgetTheme(key, 0xFF101510.toInt(), 0xFF1D5F22.toInt(), 0xFFFFFFFF.toInt(), 0xFF7CFF00.toInt())
        "youtube" -> WidgetTheme(key, 0xFF181818.toInt(), 0xFF2B0E14.toInt(), 0xFFFFFFFF.toInt(), 0xFFFF8A9F.toInt())
        "steam" -> WidgetTheme(key, 0xFF171D25.toInt(), 0xFF1B3D55.toInt(), 0xFFD6E9F8.toInt(), 0xFF66C0F4.toInt())
        else -> WidgetTheme("classic", 0xFF173A8E.toInt(), 0xFF315AB5.toInt(), 0xFFFFFFFF.toInt(), 0xFFDDE8FF.toInt())
    }
}

private fun themedTypeface(context: Context, theme: WidgetTheme, style: Int): Typeface {
    if (theme.key != "minecraft") {
        return Typeface.create(Typeface.DEFAULT, style)
    }
    return try {
        val base = context.resources.getFont(R.font.minecraft_custom)
        Typeface.create(base, style)
    } catch (_: Exception) {
        Typeface.create(Typeface.MONOSPACE, style)
    }
}

private fun readWidgetClasses(context: Context, widgetId: Int): List<WidgetClass> {
    val raw = context
        .getSharedPreferences(SNAPSHOT_PREFS, Context.MODE_PRIVATE)
        .getString(SNAPSHOT_KEY, null)
        ?: return emptyList()

    return try {
        val today = SimpleDateFormat(DATE_PATTERN, Locale.US).format(Date())
        val now = SimpleDateFormat(DATE_TIME_PATTERN, Locale.US).format(Date())
        val selectedDate = if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            today
        } else {
            context
                .getSharedPreferences(
                    ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
                    Context.MODE_PRIVATE,
                )
                .getString(ScheduleWidgetProvider.selectedDateKey(widgetId), null)
                ?.takeIf(::isIsoDate)
                ?: today
        }

        val records = JSONObject(raw).optJSONArray("records") ?: return emptyList()
        val allItems = ArrayList<WidgetClass>(records.length())
        for (i in 0 until records.length()) {
            val record = records.optJSONObject(i) ?: continue
            if (record.optBoolean("isExam", false)) {
                continue
            }
            val startAt = record.optString("startAt")
            val endAt = record.optString("endAt")
            if (startAt.length < 16 || endAt.length < 16) {
                continue
            }

            val dateKey = startAt.take(10)
            if (!isIsoDate(dateKey)) {
                continue
            }
            val room = record.optString("room")
            val date = "${dateKey.substring(8, 10)}/${dateKey.substring(5, 7)}"
            val roomAndDate = listOf(room, date)
                .filter { it.isNotBlank() }
                .joinToString(" • ")
            val startTime = startAt.substring(11, 16)
            val endTime = if (endAt.length >= 16) endAt.substring(11, 16) else ""
            val subject = record.optString("subjectName").ifBlank { "Lịch học Phenikaa" }
            val id = record.optString("id").ifBlank { "$startAt|$subject|$room" }
            allItems.add(
                WidgetClass(
                    id = id,
                    subject = subject,
                    room = roomAndDate,
                    time = if (endTime.isBlank()) startTime else "$startTime - $endTime",
                    startAt = startAt,
                    endAt = endAt,
                    dateKey = dateKey,
                ),
            )
        }

        // Index zero is the selected date (today by default). Future dates follow in
        // ascending order. Older dates are also ascending, so the final item is the
        // day immediately before the selected date. With loopViews enabled, swiping
        // backwards from the selected day therefore reaches the previous day.
        // Keep the complete collection: truncating this list used to remove the most
        // recent past dates because they intentionally sit at the end for loop order.
        val ordered = allItems.sortedWith(
            Comparator { a, b ->
                val aGroup = dateGroup(a.dateKey, selectedDate)
                val bGroup = dateGroup(b.dateKey, selectedDate)
                if (aGroup != bGroup) {
                    return@Comparator aGroup.compareTo(bGroup)
                }

                when (aGroup) {
                    0 -> {
                        if (selectedDate == today) {
                            val aUpcoming = a.endAt.take(19) >= now
                            val bUpcoming = b.endAt.take(19) >= now
                            if (aUpcoming != bUpcoming) {
                                return@Comparator if (aUpcoming) -1 else 1
                            }
                            if (aUpcoming) {
                                a.startAt.compareTo(b.startAt)
                            } else {
                                b.startAt.compareTo(a.startAt)
                            }
                        } else {
                            a.startAt.compareTo(b.startAt)
                        }
                    }
                    1 -> a.startAt.compareTo(b.startAt)
                    else -> a.startAt.compareTo(b.startAt)
                }
            },
        )

        val selectedHasSchedule = ordered.any { it.dateKey == selectedDate }
        val result = ArrayList<WidgetClass>(ordered.size + if (selectedHasSchedule) 0 else 1)
        if (!selectedHasSchedule) {
            val displayDate = "${selectedDate.substring(8, 10)}/${selectedDate.substring(5, 7)}"
            result.add(
                WidgetClass(
                    id = "empty-day-$selectedDate",
                    subject = "Không có lịch học",
                    room = if (selectedDate == today) "Hôm nay • $displayDate" else displayDate,
                    time = "",
                    startAt = "${selectedDate}T00:00:00",
                    endAt = "${selectedDate}T23:59:59",
                    dateKey = selectedDate,
                ),
            )
        }
        result.addAll(ordered)
        result
    } catch (_: Exception) {
        emptyList()
    }
}

private fun dateGroup(date: String, selectedDate: String): Int = when {
    date == selectedDate -> 0
    date > selectedDate -> 1
    else -> 2
}

private fun isIsoDate(value: String): Boolean =
    value.length == 10 &&
        value[4] == '-' &&
        value[7] == '-' &&
        value.substring(0, 4).all(Char::isDigit) &&
        value.substring(5, 7).all(Char::isDigit) &&
        value.substring(8, 10).all(Char::isDigit)

private data class WidgetClass(
    val id: String,
    val subject: String,
    val room: String,
    val time: String,
    val startAt: String,
    val endAt: String,
    val dateKey: String,
) {
    val stableId: Long
        get() = id.hashCode().toLong()
}

private const val SNAPSHOT_PREFS = "FlutterSharedPreferences"
private const val SNAPSHOT_KEY = "flutter.better_phenikaa_snapshot_v1"
private const val THEME_KEY = "flutter.appTheme"
private const val DATE_PATTERN = "yyyy-MM-dd"
private const val DATE_TIME_PATTERN = "yyyy-MM-dd'T'HH:mm:ss"
private const val DEFAULT_WIDGET_WIDTH_DP = 320
private const val DEFAULT_WIDGET_HEIGHT_DP = 64

private const val CONTENT_LEFT_FRACTION = 0.095f
private const val TITLE_RIGHT_FRACTION = 0.86f
private const val DETAIL_RIGHT_FRACTION = 0.86f
private const val SUBJECT_TEXT_HEIGHT_FRACTION = 0.205f
private const val DETAIL_TEXT_HEIGHT_FRACTION = 0.14f
private const val SUBJECT_BASELINE_HEIGHT_FRACTION = 0.39f
private const val DETAIL_BASELINE_HEIGHT_FRACTION = 0.77f
private const val DETAIL_GAP_WIDTH_FRACTION = 0.03f
private const val MIN_TITLE_WIDTH_FRACTION = 0.30f
private const val MIN_DETAIL_WIDTH_FRACTION = 0.12f
private const val MIN_SUBJECT_FIT_SCALE = 0.64f
private const val MIN_DETAIL_FIT_SCALE = 0.72f
