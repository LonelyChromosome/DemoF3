package vn.edu.phenikaa.better_phenikaa_schedule

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews

/** One visual state for the one-shot manual sync shared by both widget providers. */
internal object WidgetSyncIndicator {
    private enum class Phase { IDLE, SPINNING, SUCCESS }
    private val handler = Handler(Looper.getMainLooper())
    @Volatile private var phase = Phase.IDLE
    private var generation = 0
    @Volatile private var step = 0
    private const val FRAME_DELAY_MS = 90L
    private const val FRAME_COUNT = 12
    private const val SUCCESS_HOLD_MS = 1_000L

    fun start(context: Context) {
        val appContext = context.applicationContext
        handler.post {
            phase = Phase.SPINNING
            step = 0
            val current = ++generation
            spin(appContext, current)
        }
    }

    fun finish(context: Context, succeeded: Boolean) {
        val appContext = context.applicationContext
        handler.post {
            val current = ++generation
            phase = if (succeeded) Phase.SUCCESS else Phase.IDLE
            updateIcons(appContext)
            if (succeeded) handler.postDelayed({
                if (generation == current && phase == Phase.SUCCESS) {
                    phase = Phase.IDLE
                    updateIcons(appContext)
                }
            }, SUCCESS_HOLD_MS)
        }
    }

    fun applyToSmall(context: Context, views: RemoteViews) =
        apply(context, views, R.id.widget_reload)

    fun applyToOverview(context: Context, views: RemoteViews) =
        apply(context, views, R.id.overview_reload)

    private fun spin(context: Context, current: Int) {
        if (generation != current || phase != Phase.SPINNING) return
        updateIcons(context)
        step = (step + 1) % FRAME_COUNT
        handler.postDelayed({ spin(context, current) }, FRAME_DELAY_MS)
    }

    private fun updateIcons(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for ((provider, layout, icon) in listOf(
            Triple(ScheduleWidgetProvider::class.java, R.layout.schedule_widget, R.id.widget_reload),
            Triple(OverviewWidgetProvider::class.java, R.layout.overview_widget, R.id.overview_reload),
        )) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            if (ids.isEmpty()) continue
            val views = RemoteViews(context.packageName, layout)
            apply(context, views, icon)
            manager.partiallyUpdateAppWidget(ids, views)
        }
    }

    private fun apply(context: Context, views: RemoteViews, icon: Int) {
        val description = when (phase) {
            Phase.IDLE -> "Làm mới widget và đồng bộ QLĐT"
            Phase.SPINNING -> "Đang đồng bộ QLĐT"
            Phase.SUCCESS -> "Đồng bộ thành công"
        }
        when (phase) {
            Phase.IDLE -> views.setImageViewResource(icon, R.drawable.ic_widget_reload)
            Phase.SUCCESS -> views.setImageViewResource(icon, R.drawable.ic_widget_check)
            Phase.SPINNING -> views.setImageViewBitmap(icon, rotatedReload(context, step * 360f / FRAME_COUNT))
        }
        views.setInt(icon, "setColorFilter", ScheduleWidgetProvider().overviewColors(context).second)
        views.setContentDescription(if (icon == R.id.widget_reload) R.id.widget_reload_hit else icon,
            description)
    }

    private fun rotatedReload(context: Context, degrees: Float): Bitmap {
        val size = (24 * context.resources.displayMetrics.density).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.rotate(degrees, size / 2f, size / 2f)
        context.getDrawable(R.drawable.ic_widget_reload)?.apply {
            setBounds(0, 0, size, size)
            draw(canvas)
        }
        return bitmap
    }
}
