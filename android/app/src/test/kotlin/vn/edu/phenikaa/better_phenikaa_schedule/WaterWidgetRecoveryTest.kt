package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class WaterWidgetRecoveryTest {
    private val context get() = RuntimeEnvironment.getApplication()
    private fun config(fill: Double = .32, color: Int = 0xFFAC70FF.toInt()) =
        WidgetThemeV14(waterCooling = JSONObject().put("schema", 2).put("fill", fill)
            .put("mode", "static").put("colors", JSONArray().put(color.toLong() and 0xFFFFFFFFL))
            .put("brightness", 1).put("border", true).toString())
    private fun selectWater() {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
            .clear().putString("flutter.appTheme", "water_cooling").commit()
    }
    private fun pixels(b: Bitmap): IntArray = IntArray(b.width*b.height).also {
        b.getPixels(it, 0, b.width, 0, 0, b.width, b.height)
    }
    private fun save(b: Bitmap, name: String) {
        val dir = File("/tmp/bpa-widget-qa").apply { mkdirs() }
        File(dir, "$name.png").outputStream().use { b.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
    private fun sampleSchedule() {
        val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val item = JSONObject().put("id", "one")
            .put("subjectName", "Lập trình cho thiết bị di động")
            .put("room", "A6-403.404 (PC)").put("startAt", "${date}T06:45:00")
            .put("endAt", "${date}T09:25:00")
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
            .putString("flutter.better_phenikaa_widget_snapshot_v1", JSONObject()
                .put("classes", JSONArray().put(item)).put("exams", JSONArray()).toString()).commit()
    }

    @Test fun threeRealRenderersPreserveBoundsAndDoNotUseAppWaterLevel() {
        selectWater(); sampleSchedule()
        val palette = NativeWidgetPalette.read(context)
        for (surface in WidgetSurface.entries) {
            val height = if(surface == WidgetSurface.SMALL) 90 else 190
            val a = NativeWidgetPreviewRenderer.render(context, surface, 360, height, config(.1), palette)
            val b = NativeWidgetPreviewRenderer.render(context, surface, 360, height, config(.9), palette)
            assertArrayEquals("$surface should be full fit", pixels(a), pixels(b))
            assertEquals(0, Color.alpha(a.getPixel(0,0)))
            save(a, surface.wireName)
            a.recycle(); b.recycle()
        }
    }

    @Test fun draftColorAffectsSmallCoverAndLargeCardWithoutChangingAppliedPreferences() {
        selectWater(); sampleSchedule()
        val palette = NativeWidgetPalette.read(context)
        for(surface in listOf(WidgetSurface.SMALL, WidgetSurface.LARGE)) {
            val a = NativeWidgetPreviewRenderer.render(context,surface,360,190,config(color=Color.RED),palette)
            val b = NativeWidgetPreviewRenderer.render(context,surface,360,190,config(color=Color.BLUE),palette)
            assertFalse("draft must reach actual compositor $surface", pixels(a).contentEquals(pixels(b)))
            a.recycle();b.recycle()
        }
        assertEquals("water_cooling", NativeWidgetPalette.read(context).key)
    }

    @Test fun widget2PersonalPhotoAndCropSurviveWaterConfigurationRoundtrip() {
        selectWater()
        val photo=Bitmap.createBitmap(500,200,Bitmap.Config.ARGB_8888)
        Canvas(photo).drawColor(Color.GREEN)
        val file=File(context.cacheDir,"user-photo.png")
        file.outputStream().use{photo.compress(Bitmap.CompressFormat.PNG,100,it)};photo.recycle()
        val original=config().copy(widget2ImagePath=file.absolutePath,
            widget2ImageCrop=WidgetImageCrop(.4f,0f,1f,1f))
        val restored=WidgetThemeV14.fromJson(original.toJson().toString())
        assertEquals(original,restored)
        val b=WidgetStaticLayerRenderer.render(context,WidgetSurface.WIDGET2,360,190,restored,
            NativeWidgetPalette.read(context),useCache=false)
        val center=b.getPixel(300,90)
        assertTrue("selected photo must override preset artwork",Color.green(center)>Color.red(center)+80)
        save(b,"widget2-user-photo");b.recycle()
    }
}
