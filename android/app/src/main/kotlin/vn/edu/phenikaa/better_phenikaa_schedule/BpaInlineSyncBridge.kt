package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * A read-only, cancellable transport for the in-app 1.7 pull gesture.
 *
 * NativeQldtWidgetSync and NativeSemesterVerifier are reused unchanged.
 * This bridge NEVER writes the timetable, registered semester, widgets or
 * credentials. Dart can commit a fully verified result after the cancel check.
 */
internal class BpaInlineSyncBridge(context: Context, engine: FlutterEngine) {
    private val app = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val epoch = AtomicInteger()
    @Volatile private var running = false
    @Volatile private var active: HeadlessQldtSync? = null

    init {
        MethodChannel(engine.dartExecutor.binaryMessenger, "better_phenikaa/inline_sync")
            .setMethodCallHandler { call, reply ->
                when (call.method) {
                    "run" -> {
                        if (running) {
                            reply.error("BUSY", "Đang chờ tác vụ QLĐT trước dừng.", null)
                        } else {
                            running = true
                            val ticket = epoch.incrementAndGet()
                            executor.execute { run(ticket, reply) }
                        }
                    }
                    "cancel" -> {
                        epoch.incrementAndGet()
                        active?.cancel()
                        reply.success(null)
                    }
                    else -> reply.notImplemented()
                }
            }
    }

    private fun run(ticket: Int, reply: MethodChannel.Result) {
        try {
            val prefs = app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val previous = prefs.getString("flutter.better_phenikaa_snapshot_v1", null)
            val cachedRoute = prefs.getString(
                "flutter.better_phenikaa_qldt_registration_route_v1", null
            )
            if (previous.isNullOrBlank()) {
                throw IllegalStateException("Chưa có lịch QLĐT đã xác minh.")
            }
            if (ticket != epoch.get()) return cancelled(reply)
            // A first-login WebView may have authenticated in memory before
            // Android persisted its cookies. Flush only for this independent
            // pull channel, without changing widget/manual sync or adding
            // another QLĐT request to the login critical path.
            runCatching { CookieManager.getInstance().flush() }
            // Reuse the proven *existing* invisible WebView transport that
            // services manual widget sync in BPA 1.6. Unlike the experimental
            // direct-HTTP client, this follows QLĐT's actual edu.makeRequest
            // authentication and works with the user's established session.
            // Reuse ONLY its read result; this bridge never calls the worker
            // or the worker's storage code.
            val sync = HeadlessQldtSync(app, cachedRoute, inlinePull = true)
            active = sync
            val remote = sync.run()
            if (ticket != epoch.get()) return cancelled(reply)
            when (remote) {
                is HeadlessQldtSync.Result.Failure ->
                    throw IllegalStateException(remote.message)
                is HeadlessQldtSync.Result.Success -> {
                    // Native verifier is the SAME authority used by existing sync.
                    // The raw envelope is sent separately ONLY for attendance.
                    val verified = NativeSemesterVerifier.verify(
                        remote.envelope, remote.registration, previous
                    )
                    if (ticket != epoch.get()) return cancelled(reply)
                    val route = JSONObject(remote.registration)
                        .optJSONObject("route")?.toString() ?: ""
                    // The secondary attendance filter can only see lessons
                    // already accepted by NativeSemesterVerifier. Failure is
                    // strictly optional and never invalidates the timetable.
                    val attendance = runCatching {
                        BpaVerifiedAttendanceFilter.fromVerifiedEnvelope(
                            remote.envelope, verified.appSnapshot
                        )
                    }.getOrDefault(
                        """{"response":{"Success":true,"Data":[]}}"""
                    )
                    val payload = mapOf(
                        "semester" to verified.semester,
                        "schedule" to verified.appSnapshot,
                        "registrationRoute" to route,
                        "attendanceEnvelope" to attendance,
                    )
                    main.post {
                        if (ticket == epoch.get()) reply.success(payload)
                        else reply.error("CANCELLED", "Đã hủy đồng bộ.", null)
                    }
                }
            }
        } catch (error: Exception) {
            main.post {
                if (ticket != epoch.get()) reply.error("CANCELLED", "Đã hủy đồng bộ.", null)
                else reply.error("QLDT_SYNC_FAILED", error.message?.take(180), null)
            }
        } finally {
            active = null
            running = false
        }
    }

    private fun cancelled(reply: MethodChannel.Result) {
        main.post { reply.error("CANCELLED", "Đã hủy đồng bộ.", null) }
    }
}
