package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.BroadcastReceiver.PendingResult
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

class Widget2Provider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        if (ids.isNotEmpty()) {
            WidgetDayChangeReceiver.scheduleNext(context)
            WidgetTimeThemeReceiver.scheduleNext(context)
        }
        ids.forEach { id ->
            WidgetRenderDispatcher.render(context, manager,
                WidgetRenderRequest(WidgetSurface.WIDGET2, id, forceStaticLayer = true))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, manager, appWidgetId, newOptions)
        state(context).edit().remove(staticTokenKey(appWidgetId)).apply()
        renderFromDispatcher(context, manager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action !in setOf(ACTION_PREVIOUS, ACTION_NEXT, ACTION_MODE, ACTION_RELOAD)) {
            super.onReceive(context, intent)
            return
        }
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID)
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
        when (action) {
            ACTION_RELOAD -> {
                // Reload uses the one shared unique WorkManager job and keeps the
                // instance's selected day/photo untouched.
                WidgetManualSync.request(context)
                renderFromDispatcher(context, AppWidgetManager.getInstance(context), id,
                    fadeContent = true)
            }
            ACTION_PREVIOUS, ACTION_NEXT -> {
                val direction = if (action == ACTION_NEXT) 1 else -1
                animateDay(context, id, direction, goAsync())
            }
            ACTION_MODE -> animateFlip(context, id, goAsync())
        }
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        super.onDeleted(context, ids)
        val stateEditor = state(context).edit()
        val selection = context.getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
            Context.MODE_PRIVATE,
        ).edit()
        ids.forEach { id ->
            stateEditor.remove(modeKey(id)).remove(staticTokenKey(id)).remove(generationKey(id))
            selection.remove(ScheduleWidgetProvider.selectedDateKey(id))
        }
        stateEditor.apply()
        selection.apply()
    }

    internal fun renderFromDispatcher(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        forceStaticLayer: Boolean = false,
        fadeContent: Boolean = false,
    ) {
        val size = WidgetHostSizeResolver.currentSize(
            context,
            manager.getAppWidgetOptions(id),
            DEFAULT_WIDTH_DP,
            DEFAULT_HEIGHT_DP,
        )
        val density = context.resources.displayMetrics.density
        val widthDp = size.width.coerceAtLeast(250f)
        val heightDp = size.height.coerceAtLeast(110f)
        val widthPx = (widthDp * density).roundToInt().coerceIn(1, 1600)
        val heightPx = (heightDp * density).roundToInt().coerceIn(1, 1000)
        val contentWidthPx = (widthPx * CONTENT_FRACTION).roundToInt().coerceAtLeast(1)
        val date = selectedDate(context, id)
        val examMode = state(context).getBoolean(modeKey(id), false)
        val items = WidgetSnapshotStore.readOverviewForDate(context, date, examMode)
        val dynamic = Widget2BitmapRenderer.content(
            context, contentWidthPx, heightPx, date, examMode, items,
        )
        val palette = NativeWidgetPalette.read(context)
        val config = WidgetThemeV14.read(context)
        val source = if (config.widget2ImagePath.isBlank()) null else java.io.File(config.widget2ImagePath)
        val token = widget2StaticLayerToken(
            widthPx,
            heightPx,
            palette,
            config,
            source?.lastModified() ?: 0L,
            source?.length() ?: 0L,
        )
        val previousToken = state(context).getString(staticTokenKey(id), null)
        val views = baseViews(context, id, palette, examMode)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutWidth(R.id.widget2_content_layer,
                widthDp * CONTENT_FRACTION, TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(R.id.widget2_content_layer,
                heightDp, TypedValue.COMPLEX_UNIT_DIP)
        }
        val firstFrame = if (fadeContent) Widget2BitmapRenderer.fadeFrame(dynamic, 0f)
            else dynamic
        views.setImageViewBitmap(R.id.widget2_content_layer, firstFrame)
        if (forceStaticLayer || previousToken != token) {
            views.setImageViewBitmap(
                R.id.widget2_static_layer,
                WidgetStaticLayerRenderer.render(
                    context, WidgetSurface.WIDGET2, widthPx, heightPx, config, palette,
                ),
            )
            manager.updateAppWidget(id, views)
            state(context).edit().putString(staticTokenKey(id), token).apply()
        } else {
            manager.partiallyUpdateAppWidget(id, views)
        }
        if (fadeContent) {
            firstFrame.recycle()
            animateRefresh(context, manager, id, dynamic)
        }
    }

    private fun animateRefresh(
        context: Context, manager: AppWidgetManager, id: Int, next: Bitmap,
    ) {
        val prefs = state(context)
        val generation = prefs.getInt(generationKey(id), 0) + 1
        prefs.edit().putInt(generationKey(id), generation).apply()
        val handler = Handler(Looper.getMainLooper())
        val frames = 7
        repeat(frames) { index ->
            handler.postDelayed({
                if (prefs.getInt(generationKey(id), 0) == generation) {
                    val progress = (index + 1).toFloat() / frames
                    val frame = Widget2BitmapRenderer.fadeFrame(next, progress)
                    val views = RemoteViews(context.packageName, R.layout.widget2)
                    views.setImageViewBitmap(R.id.widget2_content_layer, frame)
                    manager.partiallyUpdateAppWidget(id, views)
                    frame.recycle()
                }
                if (index == frames - 1) next.recycle()
            }, index * 45L)
        }
    }

    private fun animateDay(
        context: Context,
        id: Int,
        direction: Int,
        pending: PendingResult,
    ) {
        val manager = AppWidgetManager.getInstance(context)
        val oldDate = selectedDate(context, id)
        val calendar = Calendar.getInstance().apply {
            time = DATE_FORMAT.parse(oldDate) ?: Date()
            add(Calendar.DAY_OF_MONTH, direction)
        }
        val nextDate = DATE_FORMAT.format(calendar.time)
        context.getSharedPreferences(ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
            Context.MODE_PRIVATE).edit()
            .putString(ScheduleWidgetProvider.selectedDateKey(id), nextDate).apply()
        val examMode = state(context).getBoolean(modeKey(id), false)
        animate(context, manager, id, oldDate, examMode, nextDate, examMode,
            direction, flip = false, pending = pending)
    }

    private fun animateFlip(context: Context, id: Int, pending: PendingResult) {
        val manager = AppWidgetManager.getInstance(context)
        val prefs = state(context)
        val previous = prefs.getBoolean(modeKey(id), false)
        val next = !previous
        if (next) ExamChangeNotifier.acknowledge(context)
        prefs.edit().putBoolean(modeKey(id), next).apply()
        val date = selectedDate(context, id)
        animate(context, manager, id, date, previous, date, next,
            direction = 0, flip = true, pending = pending)
    }

    private fun animate(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        oldDate: String,
        oldExam: Boolean,
        nextDate: String,
        nextExam: Boolean,
        direction: Int,
        flip: Boolean,
        pending: PendingResult,
    ) {
        val size = WidgetHostSizeResolver.currentSize(context, manager.getAppWidgetOptions(id),
            DEFAULT_WIDTH_DP, DEFAULT_HEIGHT_DP)
        val density = context.resources.displayMetrics.density
        val width = (size.width.coerceAtLeast(250f) * density * CONTENT_FRACTION)
            .roundToInt().coerceIn(1, (1600 * CONTENT_FRACTION).roundToInt())
        val height = (size.height.coerceAtLeast(110f) * density).roundToInt().coerceIn(1, 1000)
        val old = Widget2BitmapRenderer.content(context, width, height, oldDate, oldExam,
            WidgetSnapshotStore.readOverviewForDate(context, oldDate, oldExam))
        val next = Widget2BitmapRenderer.content(context, width, height, nextDate, nextExam,
            WidgetSnapshotStore.readOverviewForDate(context, nextDate, nextExam))
        val state = state(context)
        val generation = state.getInt(generationKey(id), 0) + 1
        state.edit().putInt(generationKey(id), generation).apply()
        val frames = if (flip) 12 else 10
        val delay = if (flip) 36L else 30L
        val handler = Handler(Looper.getMainLooper())
        repeat(frames) { frameIndex ->
            handler.postDelayed({
                if (state.getInt(generationKey(id), 0) != generation) {
                    if (frameIndex == frames - 1) pending.finish()
                    return@postDelayed
                }
                val progress = frameIndex.toFloat() / (frames - 1)
                val frame = if (flip) Widget2BitmapRenderer.flipFrame(old, next, progress)
                    else Widget2BitmapRenderer.verticalFrame(old, next, progress, direction)
                val views = baseViews(context, id, NativeWidgetPalette.read(context), nextExam)
                views.setImageViewBitmap(R.id.widget2_content_layer, frame)
                manager.partiallyUpdateAppWidget(id, views)
                frame.recycle()
                if (frameIndex == frames - 1) {
                    old.recycle()
                    next.recycle()
                    pending.finish()
                }
            }, frameIndex * delay)
        }
    }

    private fun baseViews(
        context: Context,
        id: Int,
        palette: NativeWidgetPalette,
        examMode: Boolean,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget2)
        listOf(R.id.widget2_previous, R.id.widget2_next, R.id.widget2_calendar,
            R.id.widget2_reload).forEach { views.setInt(it, "setColorFilter", palette.icon) }
        WidgetSyncIndicator.applyToWidget2(context, views)
        val hasExams = WidgetSnapshotStore.readOverviewForDate(
            context,
            selectedDate(context, id),
            true,
        ).isNotEmpty()
        views.setImageViewResource(R.id.widget2_mode,
            if (examMode) R.drawable.ic_widget_back else R.drawable.ic_widget_bell)
        views.setInt(R.id.widget2_mode, "setColorFilter",
            if (!examMode && hasExams) 0xFFFF4C5B.toInt() else palette.icon)
        views.setOnClickPendingIntent(R.id.widget2_previous, action(context, id, ACTION_PREVIOUS))
        views.setOnClickPendingIntent(R.id.widget2_next, action(context, id, ACTION_NEXT))
        views.setOnClickPendingIntent(R.id.widget2_reload, action(context, id, ACTION_RELOAD))
        views.setOnClickPendingIntent(R.id.widget2_mode, action(context, id, ACTION_MODE))
        val dateIntent = Intent(context, WidgetDatePickerActivity::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            data = Uri.parse("better-phenikaa://widget2/$id/date-picker")
        }
        views.setOnClickPendingIntent(R.id.widget2_calendar,
            PendingIntent.getActivity(context, id + 600_000, dateIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        val open = PendingIntent.getActivity(
            context,
            id + 700_000,
            Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                data = Uri.parse("better-phenikaa://widget2/$id/open")
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget2_content_layer, open)
        views.setOnClickPendingIntent(R.id.widget2_static_layer, open)
        return views
    }

    private fun action(context: Context, id: Int, name: String): PendingIntent {
        val intent = Intent(context, Widget2Provider::class.java).apply {
            action = name
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            data = Uri.parse("better-phenikaa://widget2/$id/$name")
        }
        return PendingIntent.getBroadcast(context, id * 10 + name.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun selectedDate(context: Context, id: Int): String {
        val today = DATE_FORMAT.format(Date())
        val saved = context.getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
            Context.MODE_PRIVATE,
        ).getString(ScheduleWidgetProvider.selectedDateKey(id), null)
        return WidgetRefreshDecision.selectedDate(saved, today)
    }

    private fun state(context: Context) =
        context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)

    private fun modeKey(id: Int) = "mode_$id"
    private fun staticTokenKey(id: Int) = "static_token_$id"
    private fun generationKey(id: Int) = "animation_generation_$id"

    companion object {
        private const val ACTION_PREVIOUS =
            "vn.edu.phenikaa.better_phenikaa_schedule.WIDGET2_PREVIOUS"
        private const val ACTION_NEXT =
            "vn.edu.phenikaa.better_phenikaa_schedule.WIDGET2_NEXT"
        private const val ACTION_MODE =
            "vn.edu.phenikaa.better_phenikaa_schedule.WIDGET2_MODE"
        private const val ACTION_RELOAD =
            "vn.edu.phenikaa.better_phenikaa_schedule.WIDGET2_RELOAD"
        private const val STATE_PREFS = "better_phenikaa_widget2_state"
        private const val DEFAULT_WIDTH_DP = 320
        private const val DEFAULT_HEIGHT_DP = 150
        private const val CONTENT_FRACTION = .68f
        private val DATE_FORMAT = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            isLenient = false
        }
    }
}

/** Deliberately excludes date, mode and schedule data: those update only the dynamic layer. */
internal fun widget2StaticLayerToken(
    widthPx: Int,
    heightPx: Int,
    palette: NativeWidgetPalette,
    config: WidgetThemeV14,
    imageModifiedAt: Long,
    imageLength: Long,
): String = listOf(
    "v5-sharp-blur",
    widthPx,
    heightPx,
    palette,
    config.widget2Border,
    config.cornerRadiusDp,
    config.widget2ImagePath,
    imageModifiedAt,
    imageLength,
).joinToString("|")
