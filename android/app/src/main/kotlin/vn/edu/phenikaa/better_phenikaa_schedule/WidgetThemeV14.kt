package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import org.json.JSONObject

internal data class WidgetBorderConfig(
    val enabled: Boolean = false,
    val color: Int = 0xFFFFD66B.toInt(),
    val widthDp: Float = 1f,
    val tienMonStyle: Boolean = false,
)

internal data class WidgetThemeV14(
    val largeImagePath: String = "",
    val widget2ImagePath: String = "",
    val smallBorder: WidgetBorderConfig = WidgetBorderConfig(),
    val largeBorder: WidgetBorderConfig = WidgetBorderConfig(),
    val widget2Border: WidgetBorderConfig = WidgetBorderConfig(),
    val cornerRadiusDp: Float = 18f,
    val glassOpacity: Float = .58f,
    val glowStrength: Float = .32f,
) {
    fun border(surface: WidgetSurface): WidgetBorderConfig = when (surface) {
        WidgetSurface.SMALL -> smallBorder
        WidgetSurface.LARGE -> largeBorder
        WidgetSurface.WIDGET2 -> widget2Border
    }

    fun toJson(): JSONObject = JSONObject()
        .put("schema", 1)
        .put("largeImagePath", largeImagePath)
        .put("widget2ImagePath", widget2ImagePath)
        .put("smallBorder", smallBorder.toJson())
        .put("largeBorder", largeBorder.toJson())
        .put("widget2Border", widget2Border.toJson())
        .put("cornerRadiusDp", cornerRadiusDp.toDouble())
        .put("glassOpacity", glassOpacity.toDouble())
        .put("glowStrength", glowStrength.toDouble())

    companion object {
        fun read(context: Context): WidgetThemeV14 {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY, null) ?: return WidgetThemeV14()
            return fromJson(raw)
        }

        fun save(context: Context, config: WidgetThemeV14) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY, config.toJson().toString()).commit()
        }

        fun fromJson(raw: String?): WidgetThemeV14 = runCatching {
            val json = JSONObject(raw ?: "{}")
            WidgetThemeV14(
                largeImagePath = json.optString("largeImagePath"),
                widget2ImagePath = json.optString("widget2ImagePath"),
                smallBorder = border(json.optJSONObject("smallBorder")),
                largeBorder = border(json.optJSONObject("largeBorder")),
                widget2Border = border(json.optJSONObject("widget2Border")),
                cornerRadiusDp = json.optDouble("cornerRadiusDp", 18.0).toFloat()
                    .coerceIn(0f, 28f),
                glassOpacity = json.optDouble("glassOpacity", .58).toFloat().coerceIn(.18f, .92f),
                glowStrength = json.optDouble("glowStrength", .32).toFloat().coerceIn(0f, 1f),
            )
        }.getOrDefault(WidgetThemeV14())

        private fun border(json: JSONObject?): WidgetBorderConfig = WidgetBorderConfig(
            enabled = json?.optBoolean("enabled", false) ?: false,
            color = json?.optLong("color", 0xFFFFD66BL)?.toInt() ?: 0xFFFFD66B.toInt(),
            widthDp = (json?.optDouble("widthDp", 1.0)?.toFloat() ?: 1f).coerceIn(.5f, 8f),
            tienMonStyle = json?.optBoolean("tienMonStyle", false) ?: false,
        )

        const val PREFS = "better_phenikaa_widget_theme_v14"
        const val KEY = "config"
    }
}

private fun WidgetBorderConfig.toJson(): JSONObject = JSONObject()
    .put("enabled", enabled)
    .put("color", color.toLong())
    .put("widthDp", widthDp.toDouble())
    .put("tienMonStyle", tienMonStyle)
