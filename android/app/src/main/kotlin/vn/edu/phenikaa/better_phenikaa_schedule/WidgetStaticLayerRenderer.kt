package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.media.ExifInterface
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.Calendar
import kotlin.math.max
import kotlin.math.roundToInt

internal data class NativeWidgetPalette(
    val key: String,
    val start: Int,
    val end: Int,
    val text: Int,
    val subtext: Int,
    val icon: Int,
) {
    companion object {
        fun read(context: Context): NativeWidgetPalette {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val key = prefs.getString("flutter.appTheme", "classic") ?: "classic"
            val custom = key == "custom"
            if (!custom) return preset(key)
            return NativeWidgetPalette(key,
                prefs.getInt(MainActivity.CUSTOM_START_KEY, DEFAULT_START),
                prefs.getInt(MainActivity.CUSTOM_END_KEY, DEFAULT_END),
                prefs.getInt(MainActivity.CUSTOM_TEXT_KEY, Color.WHITE),
                prefs.getInt(MainActivity.CUSTOM_SUBTEXT_KEY, 0xFFDDE8FF.toInt()),
                prefs.getInt(MainActivity.CUSTOM_ICON_KEY, Color.WHITE))
        }

        private fun preset(key: String): NativeWidgetPalette = when (key) {
            "lol" -> NativeWidgetPalette(key, 0xFF06131A.toInt(), 0xFF0B343A.toInt(),
                0xFFF0E6D2.toInt(), 0xFFC8AA6E.toInt(), 0xFFF0E6D2.toInt())
            "valorant" -> NativeWidgetPalette(key, 0xFF0F1923.toInt(), 0xFF24313B.toInt(),
                0xFFECE8E1.toInt(), 0xFFFF7B86.toInt(), 0xFFECE8E1.toInt())
            "minecraft" -> NativeWidgetPalette(key, 0xFF3A2B20.toInt(), 0xFF6B4A2F.toInt(),
                Color.WHITE, 0xFFD8D1C9.toInt(), Color.WHITE)
            "facebook" -> NativeWidgetPalette(key, Color.WHITE, 0xFFE7F3FF.toInt(),
                0xFF050505.toInt(), 0xFF65676B.toInt(), 0xFF1877F2.toInt())
            "shopee" -> NativeWidgetPalette(key, 0xFFEE4D2D.toInt(), 0xFFFF6A3D.toInt(),
                Color.WHITE, 0xFFFFE9E1.toInt(), Color.WHITE)
            "tiktok" -> NativeWidgetPalette(key, 0xFF111111.toInt(), 0xFF2A1520.toInt(),
                Color.WHITE, 0xFF25F4EE.toInt(), Color.WHITE)
            "ben10" -> NativeWidgetPalette(key, 0xFF101510.toInt(), 0xFF1D5F22.toInt(),
                Color.WHITE, 0xFF7CFF00.toInt(), Color.WHITE)
            "youtube" -> NativeWidgetPalette(key, 0xFF181818.toInt(), 0xFF2B0E14.toInt(),
                Color.WHITE, 0xFFFF8A9F.toInt(), Color.WHITE)
            "steam" -> NativeWidgetPalette(key, 0xFF171D25.toInt(), 0xFF1B3D55.toInt(),
                0xFFD6E9F8.toInt(), 0xFF66C0F4.toInt(), 0xFFD6E9F8.toInt())
            "tien_mon_premium" -> NativeWidgetPalette(key, 0xFF12372E.toInt(),
                0xFF477B68.toInt(), 0xFFFFD66B.toInt(), 0xFFFFE7A6.toInt(),
                0xFFFFD66B.toInt())
            else -> NativeWidgetPalette("classic", DEFAULT_START, DEFAULT_END,
                Color.WHITE, 0xFFDDE8FF.toInt(), Color.WHITE)
        }

        private val DEFAULT_START = 0xFF173A8E.toInt()
        private val DEFAULT_END = 0xFF315AB5.toInt()
    }
}

/** Static image/background/border compositor shared by preview and launcher renderers. */
internal object WidgetStaticLayerRenderer {
    internal data class FloatBounds(
        val left: Float,
        val top: Float,
        val right: Float,
        val bottom: Float,
    ) {
        val width: Float get() = right - left
        val height: Float get() = bottom - top
    }

    fun decorateLarge(
        context: Context,
        base: Bitmap,
        config: WidgetThemeV14 = WidgetThemeV14.read(context),
        palette: NativeWidgetPalette = NativeWidgetPalette.read(context),
    ): Bitmap {
        val source = File(config.largeImagePath).takeIf(File::isFile)
        val clock = Calendar.getInstance()
        val timeBucket = clock.get(Calendar.HOUR_OF_DAY) * 2 + clock.get(Calendar.MINUTE) / 30
        val cacheKey = listOf(
            "large-v2", base.width, base.height, palette,
            source?.absolutePath.orEmpty(), source?.lastModified() ?: 0L,
            source?.length() ?: 0L, config.largeBorder, config.cornerRadiusDp, timeBucket,
        ).joinToString("|")
        val cached = File(cacheDirectory(context), "${sha256(cacheKey)}.png")
        if (cached.isFile) {
            BitmapFactory.decodeFile(cached.absolutePath)?.let {
                base.recycle()
                return it
            }
        }
        val result = Bitmap.createBitmap(base.width, base.height, Bitmap.Config.ARGB_8888)
        val resultCanvas = Canvas(result)
        val radius = cornerRadiusPx(context, config, result.width, result.height)
        resultCanvas.save()
        resultCanvas.clipRoundRect(
            RectF(0f, 0f, result.width.toFloat(), result.height.toFloat()),
            radius,
            radius,
        )
        resultCanvas.drawBitmap(base, 0f, 0f, null)
        base.recycle()
        val decoded = source?.let { decodeOriented(it, result.width * 2, result.height * 2) }
        if (decoded != null) {
            drawContain(
                resultCanvas,
                decoded,
                RectF(0f, 0f, result.width.toFloat(), result.height.toFloat()),
            )
            decoded.recycle()
        }
        resultCanvas.restore()
        drawOuterBorder(
            resultCanvas,
            WidgetSurface.LARGE,
            result.width,
            result.height,
            config,
            palette,
            context.resources.displayMetrics.density,
        )
        runCatching {
            FileOutputStream(cached).use { result.compress(Bitmap.CompressFormat.PNG, 100, it) }
            trimCache(cacheDirectory(context), keep = 20)
        }
        return result
    }

    fun render(
        context: Context,
        surface: WidgetSurface,
        widthPx: Int,
        heightPx: Int,
        config: WidgetThemeV14 = WidgetThemeV14.read(context),
        palette: NativeWidgetPalette = NativeWidgetPalette.read(context),
        useCache: Boolean = true,
    ): Bitmap {
        val safeWidth = widthPx.coerceIn(1, 1600)
        val safeHeight = heightPx.coerceIn(1, 1000)
        val imagePath = when (surface) {
            WidgetSurface.SMALL -> ""
            WidgetSurface.LARGE -> config.largeImagePath
            WidgetSurface.WIDGET2 -> config.widget2ImagePath
        }
        val source = File(imagePath).takeIf { it.isFile }
        val cacheKey = listOf(
            "v4", surface.wireName, safeWidth, safeHeight, palette,
            source?.absolutePath.orEmpty(),
            source?.lastModified() ?: 0L, source?.length() ?: 0L,
            config.border(surface), config.cornerRadiusDp,
            config.glassOpacity, config.glowStrength,
        ).joinToString("|")
        val cached = File(cacheDirectory(context), "${sha256(cacheKey)}.png")
        if (useCache && cached.isFile) {
            BitmapFactory.decodeFile(cached.absolutePath)?.let { return it }
        }

        val bitmap = Bitmap.createBitmap(safeWidth, safeHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val outerRadius = cornerRadiusPx(context, config, safeWidth, safeHeight)
        canvas.save()
        canvas.clipRoundRect(
            RectF(0f, 0f, safeWidth.toFloat(), safeHeight.toFloat()),
            outerRadius,
            outerRadius,
        )
        drawThemeBase(canvas, safeWidth, safeHeight, palette)
        val decoded = source?.let { decodeOriented(it, safeWidth * 2, safeHeight * 2) }
        when (surface) {
            WidgetSurface.SMALL -> Unit
            WidgetSurface.LARGE -> decoded?.let {
                // Final 1.4 rule: keep the complete photo visible. Any unused
                // area remains the Theme Engine background; never crop/stretch.
                drawContain(canvas, it, RectF(0f, 0f, safeWidth.toFloat(), safeHeight.toFloat()))
            }
            WidgetSurface.WIDGET2 -> {
                decoded?.let {
                    drawBlurredCover(canvas, it, safeWidth, safeHeight)
                }
                if (decoded != null) {
                    val shade = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        shader = LinearGradient(
                            0f, 0f, safeWidth.toFloat(), 0f,
                            intArrayOf(0xB8000000.toInt(), 0x65000000, 0x25000000),
                            floatArrayOf(0f, .62f, 1f), Shader.TileMode.CLAMP,
                        )
                    }
                    canvas.drawRect(0f, 0f, safeWidth.toFloat(), safeHeight.toFloat(), shade)
                }
                val inset = max(7f, safeHeight * .055f)
                val imageRect = RectF(safeWidth * .69f, inset, safeWidth - inset, safeHeight - inset)
                val imageRadius = safeHeight * .09f
                canvas.drawRoundRect(imageRect, imageRadius, imageRadius,
                    Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x3AFFFFFF })
                if (decoded != null) {
                    val save = canvas.save()
                    canvas.clipRoundRect(imageRect, imageRadius, imageRadius)
                    drawContain(canvas, decoded, imageRect)
                    canvas.restoreToCount(save)
                } else {
                    val drawable = context.getDrawable(R.drawable.ic_widget_study)?.mutate()
                    drawable?.setTint(withAlpha(palette.subtext, 190))
                    val iconSize = (minOf(imageRect.width(), imageRect.height()) * .34f)
                        .roundToInt().coerceAtLeast(1)
                    val iconLeft = (imageRect.centerX() - iconSize / 2f).roundToInt()
                    val iconTop = (imageRect.centerY() - iconSize / 2f).roundToInt()
                    drawable?.setBounds(iconLeft, iconTop, iconLeft + iconSize, iconTop + iconSize)
                    drawable?.draw(canvas)
                }
                val photoBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = withAlpha(palette.text, 130)
                    style = Paint.Style.STROKE
                    strokeWidth = max(1f, safeHeight / 150f)
                }
                canvas.drawRoundRect(imageRect, imageRadius, imageRadius, photoBorder)
            }
        }
        decoded?.recycle()
        canvas.restore()
        drawOuterBorder(
            canvas,
            surface,
            safeWidth,
            safeHeight,
            config,
            palette,
            context.resources.displayMetrics.density,
        )
        if (useCache) runCatching {
            FileOutputStream(cached).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            trimCache(cacheDirectory(context), keep = 20)
        }
        return bitmap
    }

    private fun drawThemeBase(canvas: Canvas, width: Int, height: Int, palette: NativeWidgetPalette) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f, 0f, width.toFloat(), height.toFloat(),
                intArrayOf(palette.start, blend(palette.start, palette.end, .48f), palette.end),
                floatArrayOf(0f, .54f, 1f), Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
    }

    private fun drawBlurredCover(canvas: Canvas, source: Bitmap, width: Int, height: Int) {
        val tinyWidth = (width / 18).coerceAtLeast(18)
        val tinyHeight = (height / 18).coerceAtLeast(10)
        val cover = Bitmap.createBitmap(tinyWidth, tinyHeight, Bitmap.Config.ARGB_8888)
        val tinyCanvas = Canvas(cover)
        drawCover(tinyCanvas, source, RectF(0f, 0f, tinyWidth.toFloat(), tinyHeight.toFloat()))
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { isDither = true }
        canvas.drawBitmap(cover, null, Rect(0, 0, width, height), paint)
        cover.recycle()
    }

    private fun drawContain(canvas: Canvas, source: Bitmap, target: RectF) {
        val bounds = containBounds(
            source.width,
            source.height,
            target.left,
            target.top,
            target.right,
            target.bottom,
        )
        canvas.drawBitmap(source, null,
            RectF(bounds.left, bounds.top, bounds.right, bounds.bottom),
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { isDither = true })
    }

    internal fun containBounds(
        sourceWidth: Int,
        sourceHeight: Int,
        targetLeft: Float,
        targetTop: Float,
        targetRight: Float,
        targetBottom: Float,
    ): FloatBounds {
        val safeWidth = sourceWidth.coerceAtLeast(1)
        val safeHeight = sourceHeight.coerceAtLeast(1)
        val targetWidth = (targetRight - targetLeft).coerceAtLeast(0f)
        val targetHeight = (targetBottom - targetTop).coerceAtLeast(0f)
        val scale = minOf(targetWidth / safeWidth, targetHeight / safeHeight)
        val width = safeWidth * scale
        val height = safeHeight * scale
        val left = targetLeft + (targetWidth - width) / 2f
        val top = targetTop + (targetHeight - height) / 2f
        return FloatBounds(left, top, left + width, top + height)
    }

    private fun drawCover(canvas: Canvas, source: Bitmap, target: RectF) {
        val scale = max(target.width() / source.width, target.height() / source.height)
        val width = source.width * scale
        val height = source.height * scale
        val left = target.left + (target.width() - width) / 2f
        val top = target.top + (target.height() - height) / 2f
        canvas.drawBitmap(source, null, RectF(left, top, left + width, top + height),
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { isDither = true })
    }

    private fun drawOuterBorder(
        canvas: Canvas,
        surface: WidgetSurface,
        width: Int,
        height: Int,
        config: WidgetThemeV14,
        palette: NativeWidgetPalette,
        density: Float,
    ) {
        val border = config.border(surface)
        if (!border.enabled) return
        val densityScale = height / if (surface == WidgetSurface.SMALL) 64f else 150f
        val stroke = (border.widthDp * densityScale).coerceIn(1f, 16f)
        val inset = stroke / 2f + 1f
        val radius = (config.cornerRadiusDp * density)
            .coerceIn(stroke, minOf(width, height) / 2f)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (border.tienMonStyle) 0xFFFFD66B.toInt() else border.color
            style = Paint.Style.STROKE
            strokeWidth = stroke
        }
        canvas.drawRoundRect(RectF(inset, inset, width - inset, height - inset), radius, radius, paint)
        if (border.tienMonStyle) {
            paint.color = withAlpha(palette.text, 105)
            paint.strokeWidth = max(1f, stroke * .34f)
            canvas.drawRoundRect(
                RectF(inset + stroke, inset + stroke, width - inset - stroke, height - inset - stroke),
                max(1f, radius - stroke), max(1f, radius - stroke), paint,
            )
        }
    }

    private fun cornerRadiusPx(
        context: Context,
        config: WidgetThemeV14,
        width: Int,
        height: Int,
    ): Float = (config.cornerRadiusDp * context.resources.displayMetrics.density)
        .coerceIn(0f, minOf(width, height) / 2f)

    private fun decodeOriented(file: File, targetWidth: Int, targetHeight: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= targetWidth &&
            bounds.outHeight / (sample * 2) >= targetHeight) sample *= 2
        val decoded = BitmapFactory.decodeFile(file.absolutePath,
            BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
        val rotation = runCatching {
            when (ExifInterface(file.absolutePath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        }.getOrDefault(0f)
        if (rotation == 0f) return decoded
        return Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height,
            Matrix().apply { postRotate(rotation) }, true).also { decoded.recycle() }
    }

    private fun cacheDirectory(context: Context): File =
        File(context.cacheDir, "widget_v14_layers").apply { mkdirs() }

    private fun trimCache(directory: File, keep: Int) {
        directory.listFiles().orEmpty().sortedByDescending(File::lastModified)
            .drop(keep).forEach(File::delete)
    }

    private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray()).joinToString("") { "%02x".format(it) }

    private fun blend(left: Int, right: Int, amount: Float): Int = Color.argb(
        (Color.alpha(left) + (Color.alpha(right) - Color.alpha(left)) * amount).roundToInt(),
        (Color.red(left) + (Color.red(right) - Color.red(left)) * amount).roundToInt(),
        (Color.green(left) + (Color.green(right) - Color.green(left)) * amount).roundToInt(),
        (Color.blue(left) + (Color.blue(right) - Color.blue(left)) * amount).roundToInt(),
    )

    private fun withAlpha(color: Int, alpha: Int): Int =
        (color and 0x00FFFFFF) or (alpha.coerceIn(0, 255) shl 24)
}
