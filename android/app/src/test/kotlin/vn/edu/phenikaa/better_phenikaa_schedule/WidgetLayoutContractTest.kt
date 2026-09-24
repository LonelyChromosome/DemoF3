package vn.edu.phenikaa.better_phenikaa_schedule

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class WidgetLayoutContractTest {
    private val androidNamespace = "http://schemas.android.com/apk/res/android"

    private fun layout(name: String) = DocumentBuilderFactory.newInstance().apply {
        isNamespaceAware = true
    }.newDocumentBuilder().parse(
        File("src/main/res/layout/$name.xml").takeIf { it.exists() }
            ?: File("app/src/main/res/layout/$name.xml"),
    )

    private fun element(name: String, root: Element): Element =
        (0 until root.getElementsByTagName("*").length)
            .map { root.getElementsByTagName("*").item(it) as Element }
            .first { it.getAttributeNS(androidNamespace, "id") == "@+id/$name" }

    @Test fun legacySmallFrameRemainsFlatAndSwipeableWithSeparatedActions() {
        val root = layout("schedule_widget").documentElement
        assertEquals("@+id/widget_root", root.getAttributeNS(androidNamespace, "id"))
        val stack = element("widget_list", root)
        assertEquals("match_parent", stack.getAttributeNS(androidNamespace, "layout_height"))
        assertEquals("true", stack.getAttributeNS(androidNamespace, "loopViews"))
        assertEquals("5dp", element("widget_calendar", root)
            .getAttributeNS(androidNamespace, "layout_marginEnd"))
        assertEquals("5dp", element("widget_reload", root)
            .getAttributeNS(androidNamespace, "layout_marginEnd"))
        assertEquals("5dp", element("widget_mode", root)
            .getAttributeNS(androidNamespace, "layout_marginEnd"))
        assertEquals("1dp", element("widget_calendar", root)
            .getAttributeNS(androidNamespace, "layout_marginTop"))
        assertEquals("22dp", element("widget_reload", root)
            .getAttributeNS(androidNamespace, "layout_marginTop"))
        assertEquals("43dp", element("widget_mode", root)
            .getAttributeNS(androidNamespace, "layout_marginTop"))
        assertEquals("gone", element("widget_empty", root)
            .getAttributeNS(androidNamespace, "visibility"))
    }

    @Test fun overviewMatchesMockupCardStripAndLongNamesCanUseTwoLines() {
        val root = layout("overview_widget").documentElement
        assertEquals("bottom", element("overview_panel", root)
            .getAttributeNS(androidNamespace, "layout_gravity"))
        assertEquals("vertical", element("overview_cards", root)
            .getAttributeNS(androidNamespace, "orientation"))
        val card = layout("overview_widget_card").documentElement
        assertEquals("63dp", card.getAttributeNS(androidNamespace, "layout_height"))
        assertEquals("horizontal", layout("overview_widget_row").documentElement
            .getAttributeNS(androidNamespace, "orientation"))
        assertEquals("2", element("overview_card_subject", card)
            .getAttributeNS(androidNamespace, "maxLines"))
        assertTrue(element("overview_navigation", root)
            .getAttributeNS(androidNamespace, "layout_height").isNotEmpty())
    }
}
