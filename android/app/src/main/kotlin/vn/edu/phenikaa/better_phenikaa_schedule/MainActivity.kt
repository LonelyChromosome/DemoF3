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
            val oldTheme = prefs.getString(THEME_KEY, "classic") ?: "classic"

            val manager = AppWidgetManager.getInstance(this)
            val component = ComponentName(this, ScheduleWidgetProvider::class.java)
            val widgetIds = manager.getAppWidgetIds(component)
            if (widgetIds.isNotEmpty() && oldTheme != theme) {
                val provider = ScheduleWidgetProvider()
                // Phase 1: freeze a fully rendered OLD-theme card above StackView.
                // Nothing underneath is invalidated until the launcher has applied
                // this cover, so returning Home can only show the previous theme.
                provider.stageThemeTransition(this, manager, widgetIds, oldTheme, theme)
                Handler(Looper.getMainLooper()).postDelayed({
                    // Phase 2: switch the data source only after the old-theme cover
                    // has landed. Some launchers (notably MIUI/HyperOS on Android 15)
                    // may redraw the widget when the backing preference changes, so
                    // immediately re-assert the old-theme cover before refreshing the
                    // hidden collection. This prevents the target theme from leaking
                    // through and visually stacking under the transition.
                    prefs.edit().putString(THEME_KEY, theme).commit()
                    provider.stageThemeTransition(this, manager, widgetIds, oldTheme, theme)
                    provider.refreshHiddenCollection(this, manager, widgetIds, oldTheme, theme)
                }, THEME_FREEZE_SETTLE_MS)
            } else if (oldTheme != theme) {
                prefs.edit().putString(THEME_KEY, theme).commit()
            }
            result.success(widgetIds.size)
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
        private const val THEME_FREEZE_SETTLE_MS = 140L
    }
}
