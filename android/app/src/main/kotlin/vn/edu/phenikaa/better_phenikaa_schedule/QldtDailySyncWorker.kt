package vn.edu.phenikaa.better_phenikaa_schedule

import android.annotation.SuppressLint
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
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
        if (!inputData.getBoolean("manual", false)) {
            return Result.success()
        }

        DailySyncScheduler.recordStarted(applicationContext, System.currentTimeMillis())
        WidgetRefreshCoordinator.refreshOverview(applicationContext)
        try {
            val preferences = applicationContext.getSharedPreferences(
                FLUTTER_PREFERENCES,
                Context.MODE_PRIVATE,
            )
            val previousSnapshot = preferences.getString(APP_SNAPSHOT_KEY, null)
            if (previousSnapshot.isNullOrBlank()) {
                DailySyncScheduler.recordFailure(applicationContext, "Hãy đồng bộ lần đầu trong ứng dụng.")
                WidgetRefreshCoordinator.refreshOverview(applicationContext)
                return Result.success()
            }

            val synchronizer = HeadlessQldtSync(applicationContext)
            activeSync = synchronizer
            val syncResult = try {
                synchronizer.run()
            } finally {
                activeSync = null
            }
            if (isStopped) {
                return Result.success()
            }

            when (syncResult) {
                is HeadlessQldtSync.Result.Success -> {
                    val bundle = NativeSemesterVerifier.verify(
                        syncResult.envelope,
                        syncResult.registration,
                        previousSnapshot,
                    )
                    val difference = NativeSemesterDifference.compare(
                        preferences.getString(CURRENT_SEMESTER_KEY, null),
                        bundle.semester,
                    )
                    val saved = preferences.edit()
                        .putString(APP_SNAPSHOT_KEY, bundle.appSnapshot)
                        .putString(WIDGET_SNAPSHOT_KEY, bundle.widgetSnapshot)
                        .putString(CURRENT_SEMESTER_KEY, bundle.semester)
                        .putString(DIFFERENCE_KEY, difference)
                        .commit()
                    if (!saved) {
                        DailySyncScheduler.recordFailure(
                            applicationContext,
                            "Không thể ghi dữ liệu đồng bộ vào bộ nhớ cục bộ.",
                        )
                        WidgetRefreshCoordinator.refreshOverview(applicationContext)
                        return Result.success()
                    }
                    WidgetRefreshCoordinator.refreshToday(applicationContext)
                    DailySyncScheduler.recordSuccess(
                        applicationContext,
                        System.currentTimeMillis(),
                    )
                    runCatching {
                        ExamReminderScheduler.reconcile(applicationContext, bundle.semester)
                    }.onFailure {
                        DailySyncScheduler.recordFailure(
                            applicationContext,
                            "Lịch đã lưu nhưng không lên lịch được nhắc thi.",
                        )
                    }
                }
                is HeadlessQldtSync.Result.Failure -> {
                    DailySyncScheduler.recordFailure(
                        applicationContext,
                        syncResult.message,
                    )
                    WidgetRefreshCoordinator.refreshOverview(applicationContext)
                }
            }
        } catch (_: Exception) {
            DailySyncScheduler.recordFailure(
                applicationContext,
                "Dữ liệu QLĐT không hợp lệ hoặc chưa tải đủ. Hãy thử lại trong ứng dụng.",
            )
            WidgetRefreshCoordinator.refreshOverview(applicationContext)
        }
        return Result.success()
    }

    override fun onStopped() {
        activeSync?.cancel()
        super.onStopped()
    }

    private companion object {
        const val FLUTTER_PREFERENCES = "FlutterSharedPreferences"
        const val APP_SNAPSHOT_KEY = "flutter.better_phenikaa_snapshot_v1"
        const val WIDGET_SNAPSHOT_KEY = "flutter.better_phenikaa_widget_snapshot_v1"
        const val CURRENT_SEMESTER_KEY = "flutter.better_phenikaa_current_semester_v1"
        const val DIFFERENCE_KEY = "flutter.better_phenikaa_semester_difference_v1"
    }
}

private class HeadlessQldtSync(private val context: Context) {
    sealed interface Result {
        data class Success(val envelope: String, val registration: String) : Result
        data class Failure(val message: String) : Result
    }

    private val completed = AtomicBoolean(false)
    private val syncRequested = AtomicBoolean(false)
    private val pendingEnvelope = AtomicReference<String>()
    private val registrationRequested = AtomicBoolean(false)
    private val navigationRequested = AtomicBoolean(false)
    private val result = AtomicReference<Result>()
    private val latch = CountDownLatch(1)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val webViewReference = AtomicReference<WebView>()
    private var readinessAttempt = 0
    private var registrationAttempt = 0

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
        disposeWebViewAndWait()
        return result.get() ?: Result.Failure("QLĐT không trả kết quả đồng bộ.")
    }

    fun cancel() {
        complete(Result.Failure("Tác vụ đồng bộ đã dừng."))
        disposeWebViewAndWait()
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
                JavascriptResultBridge(
                    onSchedule = { envelope ->
                        mainHandler.post {
                            pendingEnvelope.set(envelope)
                            checkRegistrationPage(webView)
                        }
                    },
                    onRegistration = { registration ->
                        pendingEnvelope.get()?.let { complete(Result.Success(it, registration)) }
                    },
                    onError = { complete(Result.Failure("Không xác minh được dữ liệu QLĐT hoặc TraCuu. Hãy thử lại.")) },
                ),
                JAVASCRIPT_BRIDGE,
            )
            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView, url: String?) {
                    super.onPageFinished(view, url)
                    if (url != null && Uri.parse(url).host == QLDT_HOST) {
                        if (pendingEnvelope.get() == null) {
                            readinessAttempt = 0
                            checkSessionReady(view)
                        } else {
                            checkRegistrationPage(view)
                        }
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
                                "Không tải được QLĐT. Hãy kiểm tra mạng rồi thử lại.",
                            ),
                        )
                    }
                }

                override fun onReceivedHttpError(
                    view: WebView,
                    request: WebResourceRequest,
                    errorResponse: WebResourceResponse,
                ) {
                    super.onReceivedHttpError(view, request, errorResponse)
                    if (request.isForMainFrame) {
                        complete(
                            Result.Failure(
                                "QLĐT trả lỗi HTTP ${errorResponse.statusCode}.",
                            ),
                        )
                    }
                }

                override fun onRenderProcessGone(
                    view: WebView,
                    detail: RenderProcessGoneDetail,
                ): Boolean {
                    webViewReference.compareAndSet(view, null)
                    complete(
                        Result.Failure(
                            if (detail.didCrash()) {
                                "Tiến trình WebView nền đã bị lỗi."
                            } else {
                                "Tiến trình WebView nền đã bị hệ thống dừng."
                            },
                        ),
                    )
                    return true
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
                    window.$JAVASCRIPT_BRIDGE.onSchedule(
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
                window.$JAVASCRIPT_BRIDGE.onError('Không đọc được lịch QLĐT. Hãy thử lại.');
              }
            })();
        """.trimIndent()
        webView.evaluateJavascript(script, null)
    }

    private fun checkRegistrationPage(webView: WebView) {
        if (completed.get() || registrationRequested.get()) return
        webView.evaluateJavascript(
            "Boolean(document.querySelector('#dropSearch_HocKy') && " +
                "document.querySelector('#dropSearch_KeHoach') && " +
                "document.querySelector('#btnXemKetQuaDangKy') && " +
                "document.querySelector('#zoneKetQuaDangKy'))",
        ) { ready ->
            if (completed.get() || registrationRequested.get()) return@evaluateJavascript
            if (ready == "true") {
                registrationRequested.set(true)
                webView.evaluateJavascript(REGISTRATION_SCRIPT, null)
                return@evaluateJavascript
            }
            if (navigationRequested.compareAndSet(false, true)) {
                webView.evaluateJavascript(NAVIGATE_TRACUU_SCRIPT) { navigated ->
                    if (navigated != "true") {
                        complete(Result.Failure("Không tìm thấy trang TraCuu duy nhất."))
                    } else {
                        retryRegistration(webView)
                    }
                }
            } else {
                retryRegistration(webView)
            }
        }
    }

    private fun retryRegistration(webView: WebView) {
        if (++registrationAttempt >= 50) {
            complete(Result.Failure("Trang TraCuu không tải xong."))
        } else {
            mainHandler.postDelayed({ checkRegistrationPage(webView) }, 200L)
        }
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

    private fun disposeWebViewAndWait() {
        val dispose = {
            webViewReference.getAndSet(null)?.let { webView ->
                webView.stopLoading()
                webView.removeJavascriptInterface(JAVASCRIPT_BRIDGE)
                webView.loadUrl("about:blank")
                webView.clearHistory()
                webView.removeAllViews()
                webView.destroy()
            }
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            dispose()
            return
        }
        val cleanupLatch = CountDownLatch(1)
        mainHandler.post {
            try {
                dispose()
            } finally {
                cleanupLatch.countDown()
            }
        }
        try {
            cleanupLatch.await(CLEANUP_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
    }

    private class JavascriptResultBridge(
        private val onSchedule: (String) -> Unit,
        private val onRegistration: (String) -> Unit,
        private val onError: (String) -> Unit,
    ) {
        @JavascriptInterface
        fun onSchedule(envelope: String) {
            onSchedule.invoke(envelope)
        }

        @JavascriptInterface
        fun onRegistration(registration: String) {
            onRegistration.invoke(registration)
        }

        @JavascriptInterface
        fun onError(message: String) {
            onError(message)
        }
    }

    private companion object {
        const val QLDT_URL = "https://qldtbeta.phenikaa-uni.edu.vn/"
        const val QLDT_HOST = "qldtbeta.phenikaa-uni.edu.vn"
        const val JAVASCRIPT_BRIDGE = "BetterPhenikaaNative"
        const val SYNC_TIMEOUT_SECONDS = 90L
        const val CLEANUP_TIMEOUT_SECONDS = 5L
        const val MAX_READINESS_ATTEMPTS = 35
        const val READINESS_RETRY_MILLIS = 1_000L
        const val SESSION_READY_SCRIPT = """
            Boolean(
              window.edu && edu.system && edu.system.userId &&
              edu.system.iM != null && typeof edu.system.makeRequest === 'function'
            );
        """
        const val NAVIGATE_TRACUU_SCRIPT = """
            (function () {
              const candidates = [...document.querySelectorAll('a')].filter(node => {
                const label = (node.textContent || '').toLocaleLowerCase('vi');
                return label.includes('tra cứu') && label.includes('đăng ký');
              });
              if (candidates.length !== 1) return false;
              candidates[0].click();
              return true;
            })();
        """
        const val REGISTRATION_SCRIPT = """
            (async function () {
              const fail = message => window.BetterPhenikaaNative.onError(message);
              const waitFor = async predicate => {
                for (let attempt = 0; attempt < 100; attempt++) {
                  const value = predicate();
                  if (value) return value;
                  await new Promise(resolve => setTimeout(resolve, 100));
                }
                throw Error('TraCuu chưa tải xong. Hãy thử lại.');
              };
              const date = value => {
                const match = /^(\d{2})\/(\d{2})\/(\d{4})${'$'}/.exec(value);
                if (!match) throw Error('TraCuu thiếu ngày của lớp.');
                const parsed = new Date(Number(match[3]), Number(match[2]) - 1, Number(match[1]));
                if (parsed.getFullYear() !== Number(match[3]) ||
                    parsed.getMonth() + 1 !== Number(match[2]) ||
                    parsed.getDate() !== Number(match[1])) throw Error('TraCuu có ngày không hợp lệ.');
                return match[3] + '-' + match[2] + '-' + match[1];
              };
              try {
                const semester = document.querySelector('#dropSearch_HocKy');
                const plan = document.querySelector('#dropSearch_KeHoach');
                const results = document.querySelector('#zoneKetQuaDangKy');
                const view = document.querySelector('#btnXemKetQuaDangKy');
                if (!semester || !plan || !results || !view) throw Error('Trang TraCuu chưa sẵn sàng.');
                const options = [...semester.options].map(option => {
                  const name = option.textContent.trim();
                  const match = /^(\d{4})_(\d{4})_(\d+)${'$'}/.exec(name);
                  return match && Number(match[2]) === Number(match[1]) + 1 && option.value
                    ? {value: option.value, name, year: Number(match[1]), term: Number(match[3])}
                    : null;
                }).filter(Boolean).sort((a, b) => b.year - a.year || b.term - a.term);
                if (!options.length) throw Error('TraCuu chưa có học kỳ hợp lệ.');
                const latest = options[0];
                semester.value = latest.value;
                semester.dispatchEvent(new Event('change', {bubbles: true}));
                const plans = await waitFor(() => {
                  const choices = [...plan.options].filter(option => option.value &&
                    (option.textContent.trim() === latest.name ||
                     option.textContent.trim().startsWith(latest.name + ',')));
                  return choices.length ? choices : null;
                });
                if (plans.length !== 1) throw Error('Không xác định được một kế hoạch duy nhất.');
                plan.value = plans[0].value;
                plan.dispatchEvent(new Event('change', {bubbles: true}));
                results.replaceChildren();
                view.click();
                await waitFor(() => results.querySelector('.subject-item'));
                let previous = '';
                let stable = 0;
                await waitFor(() => {
                  const current = results.innerHTML;
                  stable = current === previous ? stable + 1 : 0;
                  previous = current;
                  return stable >= 4;
                });
                if (semester.value !== latest.value || plan.value !== plans[0].value) {
                  throw Error('TraCuu đã đổi học kỳ hoặc kế hoạch.');
                }
                const subjects = [...results.querySelectorAll('.subject-item')].map(item => {
                  const heading = item.querySelector('h4');
                  const name = heading ? heading.textContent.trim().replace(/^Môn\s+/i, '').trim() : '';
                  if (!name) throw Error('TraCuu có môn thiếu tên.');
                  const classes = [...item.querySelectorAll('.classroom-section-item')].map(section => {
                    const classNode = section.querySelector('.btnChiTietLopHocPhan');
                    const name = classNode ? classNode.textContent.trim() : '';
                    const dateNode = section.querySelector('.classroom-day');
                    const match = dateNode && /(\d{2}\/\d{2}\/\d{4})\s*-\s*(\d{2}\/\d{2}\/\d{4})/.exec(dateNode.textContent);
                    if (!name || !match) throw Error('TraCuu thiếu lớp hoặc khoảng ngày.');
                    return {name, startsOn: date(match[1]), endsOn: date(match[2])};
                  });
                  return {name, classes};
                });
                window.BetterPhenikaaNative.onRegistration(JSON.stringify({
                  id: latest.name, name: latest.name, subjects
                }));
              } catch (error) {
                fail(error.message || 'Không xác minh được dữ liệu TraCuu.');
              }
            })();
        """
    }
}

internal object QldtSnapshotEncoder {
    data class SnapshotBundle(
        val appSnapshot: String,
        val widgetSnapshot: String,
    )

    fun encode(envelopeJson: String, previousSnapshot: String): SnapshotBundle {
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

        val recordsById = LinkedHashMap<String, JSONObject>()
        for (index in 0 until rawData.length()) {
            val item = rawData.optJSONObject(index) ?: continue
            parseRecord(item)?.let { record ->
                recordsById[record.getString("id")] = record
            }
        }
        if (rawData.length() > 0 && recordsById.isEmpty()) {
            throw IllegalArgumentException("Không có bản ghi QLĐT hợp lệ.")
        }
        val records = recordsById.values.sortedBy { it.optString("startAt") }
        val syncedAt = isoTimestamp(Date())

        val encodedRecords = JSONArray()
        val widgetClasses = JSONArray()
        records.forEach { record ->
            encodedRecords.put(record)
            if (!record.optBoolean("isExam", false)) {
                widgetClasses.put(
                    JSONObject()
                        .put("id", record.getString("id"))
                        .put("subjectName", record.getString("subjectName"))
                        .put("room", record.getString("room"))
                        .put("startAt", record.getString("startAt"))
                        .put("endAt", record.getString("endAt")),
                )
            }
        }
        val appSnapshot = JSONObject()
            .put("displayName", displayName)
            .put("records", encodedRecords)
            .put("syncedAt", syncedAt)
            .put("source", "qldt")
            .toString()
        val widgetSnapshot = JSONObject()
            .put("schemaVersion", 1)
            .put("generatedAt", syncedAt)
            .put("classes", widgetClasses)
            .toString()
        return SnapshotBundle(appSnapshot, widgetSnapshot)
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
        if (endAt <= startAt) {
            return null
        }
        val idPrefix = if (isExam) "exam" else "class"
        val id = listOf(
            idPrefix,
            dateText,
            subjectName,
            "$startHour:$startMinute",
            room,
            jsonString(item, "TENLOPHOCPHAN"),
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
