package vn.edu.phenikaa.better_phenikaa_schedule

import android.webkit.WebViewClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class QldtPageRetryTest {
    @Test fun transientPortalFailureRetriesOnlyTwice() {
        assertEquals(1_500L, QldtPageRetry.delayMillis(WebViewClient.ERROR_CONNECT, 0, true))
        assertEquals(3_000L, QldtPageRetry.delayMillis(WebViewClient.ERROR_TIMEOUT, 1, true))
        assertNull(QldtPageRetry.delayMillis(WebViewClient.ERROR_CONNECT, 2, true))
    }

    @Test fun certificateAndUnrelatedHostFailuresDoNotRetry() {
        assertNull(QldtPageRetry.delayMillis(
            WebViewClient.ERROR_FAILED_SSL_HANDSHAKE, 0, true))
        assertNull(QldtPageRetry.delayMillis(WebViewClient.ERROR_HOST_LOOKUP, 0, false))
    }
}
