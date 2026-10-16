package vn.edu.phenikaa.better_phenikaa_schedule

import android.graphics.Typeface
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class RetiredWidgetFontTest {
    @Test fun staleBundledFamilyUsesSystemWithoutLoadingDeletedAsset() {
        val context = RuntimeEnvironment.getApplication()
        for (weight in listOf(Typeface.NORMAL, Typeface.BOLD)) {
            assertEquals(Typeface.create(Typeface.DEFAULT, weight),
                WidgetFont.typefaceFor(context, "BatmanForever", "", weight))
        }
    }
}
