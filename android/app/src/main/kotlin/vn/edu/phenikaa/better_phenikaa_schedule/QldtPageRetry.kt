package vn.edu.phenikaa.better_phenikaa_schedule

import android.webkit.WebViewClient

/** Only transient main-frame network failures get a bounded reload. */
internal object QldtPageRetry {
    fun delayMillis(errorCode: Int, attempts: Int, samePortalHost: Boolean): Long? {
        if (!samePortalHost || attempts !in 0..1) return null
        if (errorCode !in setOf(
                WebViewClient.ERROR_HOST_LOOKUP,
                WebViewClient.ERROR_CONNECT,
                WebViewClient.ERROR_IO,
                WebViewClient.ERROR_TIMEOUT,
            )) return null
        return 1_500L * (attempts + 1)
    }
}
