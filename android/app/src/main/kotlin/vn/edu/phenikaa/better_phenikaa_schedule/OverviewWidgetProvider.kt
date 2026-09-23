package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class OverviewWidgetProvider : HomeWidgetProvider() {
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
                state.edit().putBoolean(modeKey(id), !state.getBoolean(modeKey(id), false))
                    .putInt(pageKey(id), 0).apply()
            } else {
                val direction = intent.getIntExtra(EXTRA_DIRECTION, 0).coerceIn(-1, 1)
                val items = WidgetSnapshotStore.readOverview(context, id, state.getBoolean(modeKey(id), false))
                val width = AppWidgetManager.getInstance(context).getAppWidgetOptions(id)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320)
                val size = OverviewPager.pageSize(width)
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
        appWidgetIds.forEach { id -> state.remove(pageKey(id)).remove(modeKey(id)) }
        state.apply()
    }

    private fun render(context: Context, manager: AppWidgetManager, id: Int) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        val examMode = state.getBoolean(modeKey(id), false)
        val items = WidgetSnapshotStore.readOverview(context, id, examMode)
        val width = manager.getAppWidgetOptions(id)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320)
        val height = manager.getAppWidgetOptions(id)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 150)
        val size = OverviewPager.pageSize(width)
        val page = OverviewPager.clamp(state.getInt(pageKey(id), 0), items.size, size)
        val (textColor, iconColor) = ScheduleWidgetProvider().overviewColors(context)
        val views = RemoteViews(context.packageName, R.layout.overview_widget)
        views.setImageViewBitmap(R.id.overview_background,
            ScheduleWidgetProvider().overviewBackground(context, width, height))
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val selected = context.getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS, Context.MODE_PRIVATE,
        ).getString(ScheduleWidgetProvider.selectedDateKey(id), today) ?: today
        val date = if (selected.length == 10) "${selected.substring(8, 10)}/${selected.substring(5, 7)}"
            else SimpleDateFormat("dd/MM", Locale.getDefault()).format(Date())
        views.setTextViewText(R.id.overview_title,
            if (examMode) "Lịch thi sắp tới · ${items.size} ca" else
                "${if (selected == today) "Hôm nay" else "Ngày $date"} · ${items.size} môn")
        views.setImageViewResource(R.id.overview_mode,
            if (examMode) R.drawable.ic_widget_back else R.drawable.ic_widget_bell)
        views.setContentDescription(R.id.overview_mode,
            if (examMode) "Về lịch học" else "Xem lịch thi")
        listOf(R.id.overview_title, R.id.overview_reload,
            R.id.overview_previous, R.id.overview_next, R.id.overview_empty).forEach {
            views.setTextColor(it, textColor)
        }
        views.setInt(R.id.overview_calendar, "setColorFilter", iconColor)
        views.setInt(R.id.overview_mode, "setColorFilter", iconColor)
        views.removeAllViews(R.id.overview_cards)
        OverviewPager.visible(items, page, size).forEach { item ->
            val card = RemoteViews(context.packageName, R.layout.overview_widget_card)
            card.setTextViewText(R.id.overview_card_time, item.startAt.drop(11).take(5))
            card.setTextViewText(R.id.overview_card_subject, item.subject)
            card.setTextViewText(R.id.overview_card_room, item.room)
            listOf(R.id.overview_card_time, R.id.overview_card_subject,
                R.id.overview_card_room).forEach { card.setTextColor(it, textColor) }
            views.addView(R.id.overview_cards, card)
        }
        views.setViewVisibility(R.id.overview_empty, if (items.isEmpty) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.overview_empty,
            if (examMode) "Không có lịch thi" else "Không có lịch học")
        views.setViewVisibility(R.id.overview_previous, if (page == 0) View.INVISIBLE else View.VISIBLE)
        views.setViewVisibility(R.id.overview_next,
            if (page >= OverviewPager.lastPage(items.size, size)) View.INVISIBLE else View.VISIBLE)
        views.setOnClickPendingIntent(R.id.overview_previous, action(context, id, ACTION_PAGE, -1))
        views.setOnClickPendingIntent(R.id.overview_next, action(context, id, ACTION_PAGE, 1))
        views.setOnClickPendingIntent(R.id.overview_mode, action(context, id, ACTION_MODE, 0))
        views.setOnClickPendingIntent(R.id.overview_reload, action(context, id, ACTION_RELOAD, 0))
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
        fun pageKey(id: Int) = "page_$id"
        fun modeKey(id: Int) = "mode_$id"
    }
}
