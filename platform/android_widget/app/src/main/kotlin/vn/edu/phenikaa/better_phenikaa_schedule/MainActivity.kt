package vn.edu.phenikaa.better_phenikaa_schedule

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val widgetHandler = Handler(Looper.getMainLooper())
    private var pendingWidgetFromTheme: String? = null
    private var pendingWidgetTargetTheme: String? = null
    private var pendingWidgetApply: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureDailySyncChannel(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_THEME_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "applyTheme") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val theme = call.argument<String>("theme") ?: "classic"
            val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val currentWidgetTheme = prefs.getString(THEME_KEY, "classic") ?: "classic"

            val manager = AppWidgetManager.getInstance(this)
            val component = ComponentName(this, ScheduleWidgetProvider::class.java)
            val widgetIds = manager.getAppWidgetIds(component)

            if (widgetIds.isNotEmpty() && currentWidgetTheme != theme) {
                // Do not touch RemoteViews while the settings/theme picker is still
                // on screen. Some launchers compose the activity exit surface with a
                // widget update for the first Home frame, which makes the app UI appear
                // faintly inside the widget. Keep only the latest requested target and
                // start the widget transition after Home has settled.
                pendingWidgetFromTheme = currentWidgetTheme
                pendingWidgetTargetTheme = theme
                pendingWidgetApply?.let(widgetHandler::removeCallbacks)
            } else if (widgetIds.isEmpty() && currentWidgetTheme != theme) {
                prefs.edit().putString(THEME_KEY, theme).commit()
            }

            result.success(widgetIds.size)
        }
    }

    override fun onResume() {
        super.onResume()
        // If the user returns before the delayed Home update fires, cancel it. The
        // latest target remains pending and will be applied on the next real exit.
        pendingWidgetApply?.let(widgetHandler::removeCallbacks)
        pendingWidgetApply = null
    }

    override fun onStop() {
        super.onStop()
        schedulePendingWidgetThemeForHome()
    }

    private fun schedulePendingWidgetThemeForHome() {
        val fromTheme = pendingWidgetFromTheme ?: return
        val targetTheme = pendingWidgetTargetTheme ?: return
        if (fromTheme == targetTheme) return

        pendingWidgetApply?.let(widgetHandler::removeCallbacks)
        val task = Runnable {
            val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val manager = AppWidgetManager.getInstance(this)
            val component = ComponentName(this, ScheduleWidgetProvider::class.java)
            val widgetIds = manager.getAppWidgetIds(component)

            if (widgetIds.isEmpty()) {
                prefs.edit().putString(THEME_KEY, targetTheme).commit()
                clearPendingWidgetTheme(fromTheme, targetTheme)
                return@Runnable
            }

            val provider = ScheduleWidgetProvider()
            // Home is now visible and stable: freeze an opaque OLD-theme card first.
            provider.stageThemeTransition(this, manager, widgetIds, fromTheme, targetTheme)

            widgetHandler.postDelayed({
                // Switch the hidden collection only after the old cover has landed.
                prefs.edit().putString(THEME_KEY, targetTheme).commit()
                provider.stageThemeTransition(this, manager, widgetIds, fromTheme, targetTheme)
                provider.refreshHiddenCollection(this, manager, widgetIds, fromTheme, targetTheme)
                clearPendingWidgetTheme(fromTheme, targetTheme)
            }, THEME_FREEZE_SETTLE_MS)
        }

        pendingWidgetApply = task
        widgetHandler.postDelayed(task, HOME_SURFACE_SETTLE_MS)
    }

    private fun clearPendingWidgetTheme(fromTheme: String, targetTheme: String) {
        if (
            pendingWidgetFromTheme == fromTheme &&
            pendingWidgetTargetTheme == targetTheme
        ) {
            pendingWidgetFromTheme = null
            pendingWidgetTargetTheme = null
            pendingWidgetApply = null
        }
    }

    private fun configureDailySyncChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DAILY_SYNC_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    val delayMillis = DailySyncScheduler.enable(applicationContext)
                    result.success(delayMillis)
                }
                "disable" -> {
                    DailySyncScheduler.disable(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val DAILY_SYNC_CHANNEL = "better_phenikaa/daily_sync"
        private const val WIDGET_THEME_CHANNEL = "better_phenikaa/widget_theme"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val THEME_KEY = "flutter.appTheme"
        private const val HOME_SURFACE_SETTLE_MS = 360L
        private const val THEME_FREEZE_SETTLE_MS = 140L
    }
}
