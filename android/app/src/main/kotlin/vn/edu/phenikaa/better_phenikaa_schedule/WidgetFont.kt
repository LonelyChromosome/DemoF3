package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.graphics.Typeface
import android.os.Build
import android.text.SpannableString
import android.text.Spanned
import android.text.style.TypefaceSpan
import java.io.File

/** RemoteViews accepts parcelable character styles even though it cannot set a Typeface directly. */
internal object WidgetFont {
    fun text(context: Context, value: String): CharSequence {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val family = prefs.getString(MainActivity.WIDGET_FONT_FAMILY_KEY, "").orEmpty()
        val path = prefs.getString(MainActivity.WIDGET_FONT_PATH_KEY, "").orEmpty()
        if (family.isBlank() && path.isBlank()) return value
        val style = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.P -> {
                val face = runCatching {
                    val imported = File(path)
                    val importDir = File(context.filesDir, "theme_imports").canonicalFile
                    when {
                        path.isNotBlank() && imported.canonicalFile.parentFile == importDir &&
                            imported.isFile -> Typeface.createFromFile(imported)
                        family == "MinecraftCustom" ->
                            Typeface.createFromAsset(context.assets,
                                "flutter_assets/assets/fonts/minecraft.ttf")
                        family.isNotBlank() -> Typeface.create(family, Typeface.NORMAL)
                        else -> null
                    }
                }.getOrNull() ?: return value
                TypefaceSpan(face)
            }
            family == "serif" || family == "monospace" -> TypefaceSpan(family)
            else -> return value
        }
        return SpannableString(value).apply {
            setSpan(style, 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }
}
