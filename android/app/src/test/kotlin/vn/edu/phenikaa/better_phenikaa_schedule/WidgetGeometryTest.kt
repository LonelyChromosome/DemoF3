package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetGeometryTest {
    @Test fun legacySizeKeepsOrientationPairsAndReferenceSize() {
        assertEquals(WidgetGeometry.Size(320, 140),
            WidgetGeometry.legacySize(320, 620, 64, 140, false, 320, 64))
        assertEquals(WidgetGeometry.Size(620, 64),
            WidgetGeometry.legacySize(320, 620, 64, 140, true, 320, 64))
        assertEquals(WidgetGeometry.Size(260, 190),
            WidgetGeometry.legacySize(260, 500, 105, 190, false, 320, 64))
        assertEquals(WidgetGeometry.Size(320, 64),
            WidgetGeometry.legacySize(320, 320, 64, 64, false, 320, 64))
        assertEquals(WidgetGeometry.Size(320, 64),
            WidgetGeometry.legacySize(0, 0, 0, 0, false, 320, 64))
    }

    @Test fun overviewKeepsReferenceGeometryAndFillsTallerHost() {
        val reference = WidgetGeometry.overview(150)
        assertEquals(150, reference.panelHeight)
        assertEquals(42, reference.headerHeight)
        assertEquals(24, reference.footerHeight)
        assertEquals(69, reference.cardHeight)
        assertEquals(6, reference.topPadding)
        assertEquals(4, reference.bottomPadding)

        val tall = WidgetGeometry.overview(270)
        assertEquals(270, tall.panelHeight)
        assertEquals(WidgetGeometry.overview(156).cardHeight, tall.cardHeight)
        assertEquals(270 - 156, tall.topPadding + tall.bottomPadding - 10)
        assertTrue(tall.cardHeight > 0)
        assertEquals(104, WidgetGeometry.overview(100).panelHeight)
    }
}
