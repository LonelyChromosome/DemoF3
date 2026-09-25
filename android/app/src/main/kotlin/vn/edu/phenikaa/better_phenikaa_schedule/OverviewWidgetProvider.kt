package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class OverviewWidgetProvider : HomeWidgetProvider() {
    internal fun stageThemeTransition(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id ->
            val frame = RemoteViews(context.packageName, R.layout.overview_widget)
            frame.setFloat(R.id.overview_root, "setAlpha", 1f)
            manager.partiallyUpdateAppWidget(id, frame)
        }
    }

    internal fun animateThemeTransition(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        ids.forEach { id ->
            val generation = state.getInt(transitionKey(id), 0) + 1
            state.edit().putInt(transitionKey(id), generation).apply()
            fadeThemeFrame(context, manager, id, generation, 0, fadeIn = false)
        }
    }

    private fun animateModeTransition(context: Context, manager: AppWidgetManager, id: Int) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        val generation = state.getInt(transitionKey(id), 0) + 1
        state.edit().putInt(transitionKey(id), generation).apply()
        fadeModeFrame(context, manager, id, generation, 0, false)
    }

    private fun fadeModeFrame(
        context: Context, manager: AppWidgetManager, id: Int,
        generation: Int, frame: Int, fadeIn: Boolean,
    ) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        if (state.getInt(transitionKey(id), 0) != generation) return
        val progress = frame.toFloat() / (THEME_FRAME_COUNT - 1)
        val views = RemoteViews(context.packageName, R.layout.overview_widget)
        views.setFloat(R.id.overview_root, "setAlpha", if (fadeIn) progress else 1f - progress)
        manager.partiallyUpdateAppWidget(id, views)
        if (frame + 1 < THEME_FRAME_COUNT) {
            Handler(Looper.getMainLooper()).postDelayed({
                fadeModeFrame(context, manager, id, generation, frame + 1, fadeIn)
            }, THEME_FRAME_DELAY_MS)
        } else if (!fadeIn) {
            state.edit().putBoolean(modeKey(id), !state.getBoolean(modeKey(id), false))
                .putInt(pageKey(id), 0).apply()
            render(context, manager, id, initialAlpha = 0f)
            fadeModeFrame(context, manager, id, generation, 0, true)
        }
    }

    private fun fadeThemeFrame(
        context: Context, manager: AppWidgetManager, id: Int,
        generation: Int, frame: Int, fadeIn: Boolean,
    ) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        if (state.getInt(transitionKey(id), 0) != generation) return
        val progress = frame.toFloat() / (THEME_FRAME_COUNT - 1)
        val views = RemoteViews(context.packageName, R.layout.overview_widget)
        views.setFloat(R.id.overview_root, "setAlpha", if (fadeIn) progress else 1f - progress)
        manager.partiallyUpdateAppWidget(id, views)
        if (frame + 1 < THEME_FRAME_COUNT) {
            Handler(Looper.getMainLooper()).postDelayed({
                fadeThemeFrame(context, manager, id, generation, frame + 1, fadeIn)
            }, THEME_FRAME_DELAY_MS)
        } else if (!fadeIn) {
            // Bind the new Theme Engine frame while invisible, then reveal it.
            render(context, manager, id, initialAlpha = 0f)
            fadeThemeFrame(context, manager, id, generation, 0, fadeIn = true)
        }
    }

    internal fun restoreDisplay(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        ids.forEach { id ->
            state.edit().putInt(pageKey(id), 0).apply()
            render(context, manager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_RELOAD) {
            WidgetManualSync.request(context)
            return
        }
        if (intent.action == ACTION_PAGE || intent.action == ACTION_MODE) {
            val id = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
            val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
            if (intent.action == ACTION_MODE) {
                if (!state.getBoolean(modeKey(id), false)) ExamChangeNotifier.acknowledge(context)
                animateModeTransition(context, AppWidgetManager.getInstance(context), id)
                return
            } else {
                val direction = intent.getIntExtra(EXTRA_DIRECTION, 0).coerceIn(-1, 1)
                val items = WidgetSnapshotStore.readOverview(context, id, state.getBoolean(modeKey(id), false))
                val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(id)
                val size = OverviewPager.pageSize(
                    options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320),
                    options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 160),
                )
                val next = OverviewPager.clamp(state.getInt(pageKey(id), 0) + direction, items.size, size)
                state.edit().putInt(pageKey(id), next).apply()
            }
            render(context, AppWidgetManager.getInstance(context), id)
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { render(context, appWidgetManager, it) }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE).edit()
        appWidgetIds.forEach { id ->
            state.remove(pageKey(id)).remove(modeKey(id)).remove(transitionKey(id))
        }
        state.apply()
    }

    private fun render(
        context: Context, manager: AppWidgetManager, id: Int, initialAlpha: Float = 1f,
    ) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        val examMode = state.getBoolean(modeKey(id), false)
        val items = WidgetSnapshotStore.readOverview(context, id, examMode)
        val width = manager.getAppWidgetOptions(id)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320)
        val height = manager.getAppWidgetOptions(id)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 150)
        val panelHeight = OverviewPager.panelHeight(height)
        val compact = panelHeight < 120
        val headerHeight = if (compact) 32 else if (panelHeight >= 140) 42 else 36
        val footerHeight = if (compact) 16 else if (panelHeight >= 140) 24 else 20
        val verticalPadding = if (compact) 4 else 10
        val cardHeight = panelHeight - verticalPadding - headerHeight - footerHeight - 5
        val columns = OverviewPager.columns(width)
        val size = OverviewPager.pageSize(width, height)
        val page = WidgetRefreshDecision.overviewPage(
            state.getInt(pageKey(id), 0), items.size, size,
        )
        if (page != state.getInt(pageKey(id), 0)) {
            state.edit().putInt(pageKey(id), page).apply()
        }
        val (textColor, iconColor) = ScheduleWidgetProvider().overviewColors(context)
        val views = RemoteViews(context.packageName, R.layout.overview_widget)
        val openApp = PendingIntent.getActivity(
            context, id, Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                data = Uri.parse("better-phenikaa://overview/$id/open")
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setFloat(R.id.overview_root, "setAlpha", initialAlpha)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutHeight(R.id.overview_panel, panelHeight.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP)
            val density = context.resources.displayMetrics.density
            views.setViewPadding(R.id.overview_content, (12 * density).toInt(),
                ((if (compact) 2 else 6) * density).toInt(), (12 * density).toInt(),
                ((if (compact) 2 else 4) * density).toInt())
            views.setViewLayoutHeight(R.id.overview_header, headerHeight.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(R.id.overview_footer, footerHeight.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP)
        }
        views.setTextViewTextSize(R.id.overview_title, TypedValue.COMPLEX_UNIT_SP,
            if (compact) 14f else 16f)
        views.setTextViewTextSize(R.id.overview_subtitle, TypedValue.COMPLEX_UNIT_SP,
            if (compact) 10f else 11f)
        views.setTextViewTextSize(R.id.overview_previous, TypedValue.COMPLEX_UNIT_SP,
            if (compact) 18f else 25f)
        views.setTextViewTextSize(R.id.overview_next, TypedValue.COMPLEX_UNIT_SP,
            if (compact) 18f else 25f)
        views.setImageViewBitmap(R.id.overview_background,
            ScheduleWidgetProvider().overviewBackground(context, width, panelHeight))
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val selected = context.getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS, Context.MODE_PRIVATE,
        ).getString(ScheduleWidgetProvider.selectedDateKey(id), today) ?: today
        val date = if (selected.length == 10) "${selected.substring(8, 10)}/${selected.substring(5, 7)}"
            else SimpleDateFormat("dd/MM", Locale.getDefault()).format(Date())
        val status = DailySyncScheduler.status(context)
        val error = status["lastError"] as? String
        val started = status["lastStartedAtMillis"] as? Long ?: 0L
        val succeeded = status["lastSuccessAtMillis"] as? Long ?: 0L
        views.setTextViewText(R.id.overview_title, WidgetFont.text(context, when {
            examMode -> "Lịch thi · Học kỳ hiện tại"
            else -> if (selected == today) "Hôm nay · $date" else "Ngày $date"
        }))
        views.setTextViewText(R.id.overview_subtitle,
            WidgetFont.text(context,
                if (examMode) "${items.size} môn thi sắp tới" else "${items.size} môn học"))
        views.setTextViewText(R.id.overview_status, WidgetFont.text(context, when {
            !error.isNullOrEmpty() && started > succeeded -> error
            started > succeeded -> "Đang đồng bộ QLĐT..."
            examMode && items.isNotEmpty() -> {
                val first = items.first()
                val target = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(first.dateKey)
                val todayStart = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }.timeInMillis
                val days = if (target == null) 0L else
                    ((target.time - todayStart) / 86_400_000L).coerceAtLeast(0L)
                if (days == 0L) "Có ca thi hôm nay" else "Còn $days ngày đến ca thi đầu tiên"
            }
            examMode -> "Chưa có ca thi sắp tới"
            selected == today -> "Lịch học hôm nay"
            else -> "Lịch học ngày $date"
        }))
        views.setImageViewResource(R.id.overview_mode,
            if (examMode) R.drawable.ic_widget_back else R.drawable.ic_widget_bell)
        views.setContentDescription(R.id.overview_mode,
            if (examMode) "Về lịch học" else "Xem lịch thi")
        listOf(R.id.overview_title, R.id.overview_subtitle,
            R.id.overview_status, R.id.overview_previous, R.id.overview_next,
            R.id.overview_page, R.id.overview_empty).forEach {
            views.setTextColor(it, textColor)
        }
        views.setInt(R.id.overview_calendar, "setColorFilter", iconColor)
        views.setInt(R.id.overview_emblem, "setColorFilter", iconColor)
        views.setInt(R.id.overview_mode, "setColorFilter",
            if (!examMode && WidgetSnapshotStore.readOverview(context, id, true).isNotEmpty())
                0xFFFF4C5B.toInt()
            else iconColor)
        views.setInt(R.id.overview_reload, "setColorFilter", iconColor)
        WidgetSyncIndicator.applyToOverview(context, views)
        views.removeAllViews(R.id.overview_cards)
        OverviewPager.visible(items, page, size).chunked(columns).forEachIndexed { rowIndex, rowItems ->
            val row = RemoteViews(context.packageName, R.layout.overview_widget_row)
            rowItems.forEachIndexed { columnIndex, item ->
                val card = RemoteViews(context.packageName, R.layout.overview_widget_card)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    card.setViewLayoutHeight(R.id.overview_card_root,
                        cardHeight.toFloat(), TypedValue.COMPLEX_UNIT_DIP)
                }
                card.setTextViewTextSize(R.id.overview_card_date,
                    TypedValue.COMPLEX_UNIT_SP, if (compact) 9f else 10f)
                card.setTextViewTextSize(R.id.overview_card_time,
                    TypedValue.COMPLEX_UNIT_SP, if (compact) 13f else 17f)
                card.setTextViewTextSize(R.id.overview_card_subject,
                    TypedValue.COMPLEX_UNIT_SP, if (compact) 10f else 11f)
                card.setTextViewTextSize(R.id.overview_card_room,
                    TypedValue.COMPLEX_UNIT_SP, if (compact) 9f else 10f)
                card.setTextViewTextSize(R.id.overview_card_form,
                    TypedValue.COMPLEX_UNIT_SP, if (compact) 9f else 10f)
                val colorIndex = page * size + rowIndex * columns + columnIndex
                val active = rowIndex == 0 && columnIndex == 0
                card.setImageViewBitmap(R.id.overview_card_background,
                    ScheduleWidgetProvider().overviewCardBackground(context, colorIndex, active))
                card.setTextViewText(R.id.overview_card_date, WidgetFont.text(context,
                    if (examMode) "${item.dateKey.substring(8, 10)}/${item.dateKey.substring(5, 7)}"
                    else ""))
                card.setViewVisibility(R.id.overview_card_date,
                    if (examMode) View.VISIBLE else View.GONE)
                card.setTextViewText(R.id.overview_card_time,
                    WidgetFont.text(context, item.startAt.drop(11).take(5)))
                card.setTextViewText(R.id.overview_card_subject,
                    WidgetFont.text(context, if (examMode)
                        OverviewPager.examLabel(item.subject, item.examForm)
                    else OverviewPager.compactSubject(item.subject, (width - 24) / columns)))
                card.setViewVisibility(R.id.overview_card_form, View.GONE)
                card.setContentDescription(R.id.overview_card_root, item.subject)
                card.setOnClickPendingIntent(R.id.overview_card_root, openApp)
                // The header already shows the selected date, and exam cards have their own date.
                // Keeping only the room makes four fixed slots readable on a phone.
                card.setTextViewText(R.id.overview_card_room,
                    WidgetFont.text(context, item.room.substringBefore(" • ")))
                card.setTextColor(R.id.overview_card_time,
                    ScheduleWidgetProvider().overviewTimeColor(context, colorIndex, active))
                card.setTextColor(R.id.overview_card_subject, textColor)
                listOf(R.id.overview_card_date, R.id.overview_card_form,
                    R.id.overview_card_room).forEach {
                    card.setTextColor(it, WidgetVisualPalette.withAlpha(textColor, 210))
                }
                row.addView(R.id.overview_row, card)
            }
            repeat(columns - rowItems.size) {
                val spacer = RemoteViews(context.packageName, R.layout.overview_widget_spacer)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    spacer.setViewLayoutHeight(R.id.overview_spacer_root,
                        cardHeight.toFloat(), TypedValue.COMPLEX_UNIT_DIP)
                }
                row.addView(R.id.overview_row, spacer)
            }
            views.addView(R.id.overview_cards, row)
        }
        views.setViewVisibility(R.id.overview_empty, if (items.isEmpty()) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.overview_empty,
            WidgetFont.text(context,
                if (examMode) "Không có lịch thi" else "Không có lịch học"))
        val lastPage = OverviewPager.lastPage(items.size, size)
        val showProgress = items.isNotEmpty() &&
            (examMode || (lastPage == 0 && (error.isNullOrEmpty() || started <= succeeded)))
        views.setViewVisibility(R.id.overview_progress,
            if (showProgress) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.overview_status,
            if (showProgress) View.GONE else View.VISIBLE)
        if (showProgress) {
            views.setImageViewBitmap(R.id.overview_progress,
                ScheduleWidgetProvider().overviewProgress(context, width - 24,
                    OverviewPager.visible(items, page, size).size, columns, page * size))
        }
        views.setViewVisibility(R.id.overview_navigation,
            if (lastPage == 0) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.overview_previous,
            if (page == 0) View.INVISIBLE else View.VISIBLE)
        views.setViewVisibility(R.id.overview_next,
            if (page >= lastPage) View.INVISIBLE else View.VISIBLE)
        views.setTextViewText(R.id.overview_page,
            WidgetFont.text(context, "${page + 1}/${lastPage + 1}"))
        views.setOnClickPendingIntent(R.id.overview_previous, action(context, id, ACTION_PAGE, -1))
        views.setOnClickPendingIntent(R.id.overview_next, action(context, id, ACTION_PAGE, 1))
        views.setOnClickPendingIntent(R.id.overview_mode, action(context, id, ACTION_MODE, 0))
        views.setOnClickPendingIntent(R.id.overview_reload, action(context, id, ACTION_RELOAD, 0))
        views.setOnClickPendingIntent(R.id.overview_panel, openApp)
        views.setOnClickPendingIntent(R.id.overview_empty, openApp)
        views.setOnClickPendingIntent(R.id.overview_emblem, openApp)
        views.setOnClickPendingIntent(R.id.overview_title, openApp)
        views.setOnClickPendingIntent(R.id.overview_subtitle, openApp)
        val dateIntent = Intent(context, WidgetDatePickerActivity::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            data = Uri.parse("better-phenikaa://overview/$id/date-picker")
        }
        views.setOnClickPendingIntent(R.id.overview_calendar,
            PendingIntent.getActivity(context, id, dateIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        manager.updateAppWidget(id, views)
    }

    private fun action(context: Context, id: Int, type: String, direction: Int): PendingIntent {
        val intent = Intent(context, OverviewWidgetProvider::class.java).apply {
            action = type
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            putExtra(EXTRA_DIRECTION, direction)
            data = Uri.parse("better-phenikaa://overview/$id/$type/$direction")
        }
        return PendingIntent.getBroadcast(context, id * 10 + direction + 2, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private companion object {
        const val ACTION_PAGE = "vn.edu.phenikaa.better_phenikaa_schedule.OVERVIEW_PAGE"
        const val ACTION_MODE = "vn.edu.phenikaa.better_phenikaa_schedule.OVERVIEW_MODE"
        const val ACTION_RELOAD = "vn.edu.phenikaa.better_phenikaa_schedule.OVERVIEW_RELOAD"
        const val EXTRA_DIRECTION = "direction"
        const val STATE_PREFS = "better_phenikaa_overview_state"
        const val THEME_FRAME_COUNT = 9
        const val THEME_FRAME_DELAY_MS = 30L
        fun pageKey(id: Int) = WidgetRefreshDecision.overviewPageKey(id)
        fun modeKey(id: Int) = WidgetRefreshDecision.overviewModeKey(id)
        fun transitionKey(id: Int) = "theme_transition_$id"
    }
}
