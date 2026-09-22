package vn.edu.phenikaa.better_phenikaa_schedule

import android.annotation.SuppressLint
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class QldtDailySyncWorker(
    appContext: Context,
    workerParameters: WorkerParameters,
) : Worker(appContext, workerParameters) {
    @Volatile
    private var activeSync: HeadlessQldtSync? = null

    override fun doWork(): Result {
        if (!DailySyncScheduler.isEnabled(applicationContext)) {
            return Result.success()
        }

        val preferences = applicationContext.getSharedPreferences(
            FLUTTER_PREFERENCES,
            Context.MODE_PRIVATE,
        )
        val previousSnapshot = preferences.getString(SNAPSHOT_KEY, null)
        if (previousSnapshot.isNullOrBlank()) {
            return Result.success()
        }

        val synchronizer = HeadlessQldtSync(applicationContext)
        activeSync = synchronizer
        val syncResult = try {
            synchronizer.run()
        } finally {
            activeSync = null
        }
        if (isStopped || !DailySyncScheduler.isEnabled(applicationContext)) {
            return Result.success()
        }

        return when (syncResult) {
            is HeadlessQldtSync.Result.Success -> {
                try {
                    val snapshot = QldtSnapshotEncoder.encode(
                        syncResult.envelope,
                        previousSnapshot,
                    )
                    if (!preferences.edit().putString(SNAPSHOT_KEY, snapshot).commit()) {
                        DailySyncScheduler.recordFailure(
                            applicationContext,
                            "Không thể ghi dữ liệu đồng bộ vào bộ nhớ cục bộ.",
                        )
                        return Result.success()
                    }
                    DailyWidgetRefresher.refresh(applicationContext)
                    DailySyncScheduler.recordSuccess(
                        applicationContext,
                        System.currentTimeMillis(),
                    )
                    Result.success()
                } catch (error: Exception) {
                    DailySyncScheduler.recordFailure(
                        applicationContext,
                        "Dữ liệu QLĐT không hợp lệ: " + error.message.orEmpty(),
                    )
                    Result.success()
                }
            }
            is HeadlessQldtSync.Result.Failure -> {
                DailySyncScheduler.recordFailure(applicationContext, syncResult.message)
                Result.success()
            }
        }
    }

    override fun onStopped() {
        activeSync?.cancel()
        super.onStopped()
    }

    private companion object {
        const val FLUTTER_PREFERENCES = "FlutterSharedPreferences"
        const val SNAPSHOT_KEY = "flutter.better_phenikaa_snapshot_v1"
    }
}

private class HeadlessQldtSync(private val context: Context) {
    sealed interface Result {
        data class Success(val envelope: String) : Result
        data class Failure(val message: String) : Result
    }

    private val completed = AtomicBoolean(false)
    private val syncRequested = AtomicBoolean(false)
    private val result = AtomicReference<Result>()
    private val latch = CountDownLatch(1)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val webViewReference = AtomicReference<WebView>()
    private var readinessAttempt = 0

    fun run(): Result {
        mainHandler.post(::createAndLoadWebView)
        val finished = try {
            latch.await(SYNC_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
        if (!finished) {
            complete(Result.Failure("Tác vụ QLĐT hết thời gian chờ."))
        }
        disposeWebView()
        return result.get() ?: Result.Failure("QLĐT không trả kết quả đồng bộ.")
    }

    fun cancel() {
        complete(Result.Failure("Tác vụ đồng bộ đã dừng."))
        disposeWebView()
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun createAndLoadWebView() {
        if (completed.get()) {
            return
        }
        try {
            val webView = WebView(context.applicationContext)
            webViewReference.set(webView)
            webView.settings.javaScriptEnabled = true
            webView.settings.domStorageEnabled = true
            webView.settings.databaseEnabled = true

            val cookieManager = CookieManager.getInstance()
            cookieManager.setAcceptCookie(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                cookieManager.setAcceptThirdPartyCookies(webView, true)
            }

            webView.addJavascriptInterface(
                JavascriptResultBridge(::complete),
                JAVASCRIPT_BRIDGE,
            )
            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView, url: String?) {
                    super.onPageFinished(view, url)
                    if (url != null && Uri.parse(url).host == QLDT_HOST) {
                        readinessAttempt = 0
                        checkSessionReady(view)
                    }
                }

                override fun onReceivedError(
                    view: WebView,
                    request: WebResourceRequest,
                    error: WebResourceError,
                ) {
                    super.onReceivedError(view, request, error)
                    if (request.isForMainFrame) {
                        complete(
                            Result.Failure(
                                "Không tải được QLĐT: " + error.description,
                            ),
                        )
                    }
                }
            }
            webView.loadUrl(QLDT_URL)
        } catch (error: Exception) {
            complete(
                Result.Failure(
                    "Không thể khởi tạo phiên QLĐT: " + error.message.orEmpty(),
                ),
            )
        }
    }

    private fun checkSessionReady(webView: WebView) {
        if (completed.get()) {
            return
        }
        webView.evaluateJavascript(SESSION_READY_SCRIPT) { rawResult ->
            if (completed.get()) {
                return@evaluateJavascript
            }
            if (rawResult == "true") {
                if (syncRequested.compareAndSet(false, true)) {
                    requestSchedule(webView)
                }
                return@evaluateJavascript
            }
            readinessAttempt += 1
            if (readinessAttempt >= MAX_READINESS_ATTEMPTS) {
                complete(
                    Result.Failure(
                        "Phiên QLĐT đã hết hạn; hãy mở app và đăng nhập lại.",
                    ),
                )
            } else {
                mainHandler.postDelayed(
                    { checkSessionReady(webView) },
                    READINESS_RETRY_MILLIS,
                )
            }
        }
    }

    private fun requestSchedule(webView: WebView) {
        val (startDate, endDate) = currentAcademicYearRange()
        val startJson = JSONObject.quote(startDate)
        val endJson = JSONObject.quote(endDate)
        val script = """
            (function () {
              try {
                if (!(window.edu && edu.system && edu.system.userId &&
                      edu.system.iM != null && typeof edu.system.makeRequest === 'function')) {
                  window.$JAVASCRIPT_BRIDGE.onError('Phiên QLĐT chưa sẵn sàng.');
                  return;
                }
                var requestData = {
                  action: 'SV_ThongTin_MH/DSA4BRINKCIpAiAPKSAv',
                  func: 'pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan',
                  iM: edu.system.iM,
                  strQLSV_NguoiHoc_Id: edu.system.userId,
                  strNgayBatDau: $startJson,
                  strNgayKetThuc: $endJson
                };
                edu.system.makeRequest({
                  success: function (response) {
                    var nameNode = document.querySelector('#lblHoTenNguoiDangNhap');
                    var name = nameNode ? (nameNode.textContent || '').trim() : '';
                    if (!name) {
                      var spans = document.querySelectorAll('.nav-account button > span');
                      for (var i = 0; i < spans.length; i++) {
                        var candidate = (spans[i].textContent || '').trim();
                        if (candidate) {
                          name = candidate;
                          break;
                        }
                      }
                    }
                    window.$JAVASCRIPT_BRIDGE.onResult(
                      JSON.stringify({name: name, response: response})
                    );
                  },
                  error: function () {
                    window.$JAVASCRIPT_BRIDGE.onError(
                      'QLĐT báo lỗi khi tải lịch cá nhân.'
                    );
                  },
                  type: 'POST',
                  action: requestData.action,
                  contentType: true,
                  data: requestData,
                  fakedb: []
                }, false, false, false, null);
              } catch (error) {
                window.$JAVASCRIPT_BRIDGE.onError('Lỗi QLĐT: ' + error);
              }
            })();
        """.trimIndent()
        webView.evaluateJavascript(script, null)
    }

    private fun currentAcademicYearRange(): Pair<String, String> {
        val now = Calendar.getInstance()
        val startYear = if (now.get(Calendar.MONTH) >= Calendar.AUGUST) {
            now.get(Calendar.YEAR)
        } else {
            now.get(Calendar.YEAR) - 1
        }
        return "01/08/$startYear" to "31/07/" + (startYear + 1)
    }

    private fun complete(value: Result) {
        if (completed.compareAndSet(false, true)) {
            result.set(value)
            latch.countDown()
        }
    }

    private fun disposeWebView() {
        mainHandler.post {
            webViewReference.getAndSet(null)?.let { webView ->
                webView.stopLoading()
                webView.removeJavascriptInterface(JAVASCRIPT_BRIDGE)
                webView.destroy()
            }
        }
    }

    private class JavascriptResultBridge(
        private val complete: (Result) -> Unit,
    ) {
        @JavascriptInterface
        fun onResult(envelope: String) {
            complete(Result.Success(envelope))
        }

        @JavascriptInterface
        fun onError(message: String) {
            complete(Result.Failure(message))
        }
    }

    private companion object {
        const val QLDT_URL = "https://qldtbeta.phenikaa-uni.edu.vn/"
        const val QLDT_HOST = "qldtbeta.phenikaa-uni.edu.vn"
        const val JAVASCRIPT_BRIDGE = "BetterPhenikaaNative"
        const val SYNC_TIMEOUT_SECONDS = 75L
        const val MAX_READINESS_ATTEMPTS = 35
        const val READINESS_RETRY_MILLIS = 1_000L
        const val SESSION_READY_SCRIPT = """
            Boolean(
              window.edu && edu.system && edu.system.userId &&
              edu.system.iM != null && typeof edu.system.makeRequest === 'function'
            );
        """
    }
}

private object QldtSnapshotEncoder {
    fun encode(envelopeJson: String, previousSnapshot: String): String {
        val envelope = JSONObject(envelopeJson)
        val response = envelope.optJSONObject("response")
            ?: throw IllegalArgumentException("QLĐT response is not an object.")
        if (!response.optBoolean("Success", false)) {
            throw IllegalArgumentException("QLĐT returned Success != true.")
        }
        val rawData = response.optJSONArray("Data")
            ?: throw IllegalArgumentException("QLĐT Data is not a list.")
        val previousName = runCatching {
            JSONObject(previousSnapshot).optString("displayName").trim()
        }.getOrDefault("")
        val displayName = jsonString(envelope, "name").ifBlank { previousName }

        val records = ArrayList<JSONObject>(rawData.length())
        for (index in 0 until rawData.length()) {
            val item = rawData.optJSONObject(index) ?: continue
            parseRecord(item)?.let(records::add)
        }
        records.sortBy { it.optString("startAt") }

        val encodedRecords = JSONArray()
        records.forEach { encodedRecords.put(it) }
        return JSONObject()
            .put("displayName", displayName)
            .put("records", encodedRecords)
            .put("syncedAt", isoTimestamp(Date()))
            .put("source", "qldt")
            .toString()
    }

    private fun parseRecord(item: JSONObject): JSONObject? {
        val subjectName = jsonString(item, "TENHOCPHAN")
        val dateText = jsonString(item, "NGAYHOC")
        val date = parseVietnameseDate(dateText)
        if (subjectName.isEmpty() || date == null) {
            return null
        }

        val startHour = jsonInt(item, "GIOBATDAU") ?: return null
        val startMinute = jsonInt(item, "PHUTBATDAU") ?: return null
        val endHour = jsonInt(item, "GIOKETTHUC") ?: return null
        val endMinute = jsonInt(item, "PHUTKETTHUC") ?: return null
        if (
            startHour !in 0..23 ||
            endHour !in 0..23 ||
            startMinute !in 0..59 ||
            endMinute !in 0..59
        ) {
            return null
        }

        val isExam = jsonString(item, "PHANLOAI").uppercase(Locale.ROOT) == "LICHTHI"
        val room = if (isExam) {
            firstNonEmpty(item, "PHONGHOC_TEN", "PHONGTHI")
        } else {
            firstNonEmpty(item, "PHONGHOC_TEN", "TENPHONGHOC")
        }
        val startAt = isoDateTime(date, startHour, startMinute)
        val endAt = isoDateTime(date, endHour, endMinute)
        val idPrefix = if (isExam) "exam" else "class"
        val id = listOf(
            idPrefix,
            dateText,
            subjectName,
            "$startHour:$startMinute",
            room,
        ).joinToString("|")

        return JSONObject()
            .put("id", id)
            .put("isExam", isExam)
            .put("subjectName", subjectName)
            .put("room", room)
            .put("startAt", startAt)
            .put("endAt", endAt)
            .put("className", jsonString(item, "TENLOPHOCPHAN"))
            .put("examForm", jsonString(item, "DANGKY_LOPHOCPHAN_TEN"))
            .put("periodStart", jsonInt(item, "TIETBATDAU") ?: JSONObject.NULL)
            .put("periodEnd", jsonInt(item, "TIETKETTHUC") ?: JSONObject.NULL)
    }

    private fun parseVietnameseDate(value: String): DateParts? {
        val parts = value.split('/')
        if (parts.size != 3) {
            return null
        }
        val day = parts[0].toIntOrNull() ?: return null
        val month = parts[1].toIntOrNull() ?: return null
        val year = parts[2].toIntOrNull() ?: return null
        val calendar = Calendar.getInstance().apply {
            isLenient = false
            clear()
            set(year, month - 1, day)
        }
        return runCatching {
            calendar.time
            DateParts(year, month, day)
        }.getOrNull()
    }

    private fun jsonString(source: JSONObject, key: String): String {
        val value = source.opt(key)
        return if (value == null || value === JSONObject.NULL) {
            ""
        } else {
            value.toString().trim()
        }
    }

    private fun jsonInt(source: JSONObject, key: String): Int? {
        val value = source.opt(key)
        return when (value) {
            is Number -> value.toInt()
            null, JSONObject.NULL -> null
            else -> value.toString().toIntOrNull()
        }
    }

    private fun firstNonEmpty(source: JSONObject, vararg keys: String): String {
        for (key in keys) {
            val value = jsonString(source, key)
            if (value.isNotEmpty()) {
                return value
            }
        }
        return ""
    }

    private fun isoDateTime(date: DateParts, hour: Int, minute: Int): String =
        String.format(
            Locale.US,
            "%04d-%02d-%02dT%02d:%02d:00.000",
            date.year,
            date.month,
            date.day,
            hour,
            minute,
        )

    private fun isoTimestamp(date: Date): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(date)

    private data class DateParts(val year: Int, val month: Int, val day: Int)
}

private object DailyWidgetRefresher {
    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, ScheduleWidgetProvider::class.java)
        val widgetIds = manager.getAppWidgetIds(component)
        if (widgetIds.isEmpty()) {
            return
        }

        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val selectionEditor = context.getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
            Context.MODE_PRIVATE,
        ).edit()
        widgetIds.forEach { widgetId ->
            selectionEditor
                .putString(ScheduleWidgetProvider.selectedDateKey(widgetId), today)
                .putBoolean(ScheduleWidgetProvider.resetChildKey(widgetId), true)
        }
        selectionEditor.commit()

        val widgetData = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        ScheduleWidgetProvider().onUpdate(context, manager, widgetIds, widgetData)
    }
}
