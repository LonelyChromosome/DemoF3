package vn.edu.phenikaa.better_phenikaa_schedule

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class Widget2ContractTest {
    private val androidNamespace = "http://schemas.android.com/apk/res/android"

    private fun resource(path: String): File =
        File("src/main/res/$path").takeIf(File::exists)
            ?: File("app/src/main/res/$path")

    private fun xml(path: String) = DocumentBuilderFactory.newInstance().apply {
        isNamespaceAware = true
    }.newDocumentBuilder().parse(resource(path))

    private fun ids(root: Element): Set<String> =
        (0 until root.getElementsByTagName("*").length)
            .map { root.getElementsByTagName("*").item(it) as Element }
            .map { it.getAttributeNS(androidNamespace, "id") }
            .filter(String::isNotBlank)
            .toSet()

    @Test fun widget2IsIndependentFourByTwoWithoutStackView() {
        val info = xml("xml/widget2_info.xml").documentElement
        assertEquals("4", info.getAttributeNS(androidNamespace, "targetCellWidth"))
        assertEquals("2", info.getAttributeNS(androidNamespace, "targetCellHeight"))
        val layout = xml("layout/widget2.xml")
        val allIds = ids(layout.documentElement)
        assertTrue("@+id/widget2_static_layer" in allIds)
        assertTrue("@+id/widget2_content_layer" in allIds)
        assertTrue("@+id/widget2_previous" in allIds)
        assertTrue("@+id/widget2_next" in allIds)
        assertFalse(layout.getElementsByTagName("StackView").length > 0)
    }

    @Test fun widget2ExposesCalendarReloadBellAndTwoDayButtons() {
        val allIds = ids(xml("layout/widget2.xml").documentElement)
        for (id in listOf("widget2_calendar", "widget2_reload", "widget2_mode",
            "widget2_previous", "widget2_next")) {
            assertTrue("@+id/$id" in allIds)
        }
    }

    @Test fun dispatcherHasExactlyThreeSurfaceKinds() {
        assertEquals(listOf("small", "large", "widget2"),
            WidgetSurface.entries.map(WidgetSurface::wireName))
    }

    @Test fun firstRenderFallsBackToTodayAndManualSelectionSurvivesRefresh() {
        assertEquals("2026-10-08", WidgetRefreshDecision.selectedDate(null, "2026-10-08"))
        assertEquals("2026-10-07",
            WidgetRefreshDecision.selectedDate("2026-10-07", "2026-10-08"))
    }

    @Test fun contentUsesZeroToFiveRealItemsOnly() {
        assertEquals(0, Widget2BitmapRenderer.visibleItemCount(0))
        assertEquals(1, Widget2BitmapRenderer.visibleItemCount(1))
        assertEquals(4, Widget2BitmapRenderer.visibleItemCount(4))
        assertEquals(5, Widget2BitmapRenderer.visibleItemCount(5))
        assertEquals(5, Widget2BitmapRenderer.visibleItemCount(12))
    }

    @Test fun verticalSlideDirectionsMatchUpAndDownButtons() {
        val previous = Widget2BitmapRenderer.verticalOffsets(.25f, -1, 100f)
        assertEquals(25f, previous.oldY, .001f)
        assertEquals(-75f, previous.nextY, .001f)

        val next = Widget2BitmapRenderer.verticalOffsets(.25f, 1, 100f)
        assertEquals(-25f, next.oldY, .001f)
        assertEquals(75f, next.nextY, .001f)
    }

    @Test fun staticLayerTokenChangesOnlyForStaticInputs() {
        val palette = NativeWidgetPalette("custom", 1, 2, 3, 4, 5)
        val config = WidgetThemeV14(widget2ImagePath = "/image/original.jpg")
        val first = widget2StaticLayerToken(640, 300, palette, config, 100, 200)
        val unchangedAfterScheduleRefresh = widget2StaticLayerToken(
            640, 300, palette, config, 100, 200,
        )
        assertEquals(first, unchangedAfterScheduleRefresh)
        assertNotEquals(first, widget2StaticLayerToken(640, 300, palette, config, 101, 200))
        assertNotEquals(first, widget2StaticLayerToken(
            640, 300, palette, config.copy(widget2Border = WidgetBorderConfig(enabled = true)),
            100, 200,
        ))
    }

    @Test fun portraitAndLandscapeImagesUseContainWithoutDistortion() {
        val landscape = WidgetStaticLayerRenderer.containBounds(
            1600, 900, 0f, 0f, 320f, 150f,
        )
        val portrait = WidgetStaticLayerRenderer.containBounds(
            900, 1600, 220f, 8f, 314f, 142f,
        )
        assertEquals(1600f / 900f, landscape.width / landscape.height, .001f)
        assertTrue(landscape.width <= 320f && landscape.height <= 150f)
        assertEquals(900f / 1600f, portrait.width / portrait.height, .001f)
        assertTrue(portrait.width <= 94f && portrait.height <= 134f)
    }
}
