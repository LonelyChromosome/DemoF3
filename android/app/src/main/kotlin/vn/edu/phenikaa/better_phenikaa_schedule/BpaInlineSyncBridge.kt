package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.os.Handler
import android.os.Looper
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
    @Volatile private var active: NativeQldtWidgetSync? = null

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
            val session = prefs.getString("flutter.better_phenikaa_qldt_native_session_v1", null)
            val previous = prefs.getString("flutter.better_phenikaa_snapshot_v1", null)
            if (session.isNullOrBlank() || previous.isNullOrBlank()) {
                throw IllegalStateException("Chưa có phiên QLĐT và lịch đã xác minh.")
            }
            if (ticket != epoch.get()) return cancelled(reply)
            // Initial login caches a native session before the verified QLĐT
            // display name is known. Supply the previously verified name in
            // memory; do not rewrite credentials, session or the old parser.
            val resolvedSession = JSONObject(session)
            if (resolvedSession.optString("name").isBlank()) {
                val profile = runCatching {
                    JSONObject(prefs.getString(
                        "flutter.better_phenikaa_qldt_profile_v1", "{}"
                    ) ?: "{}")
                }.getOrNull()
                val verifiedName = if (
                    profile?.optString("source") == "qldt_api_registration" &&
                    profile.optString("userId") == resolvedSession.optString("userId")
                ) profile.optString("name") else ""
                val savedName = runCatching {
                    JSONObject(previous).optString("displayName")
                }.getOrDefault("")
                val name = verifiedName.ifBlank { savedName }.trim()
                if (name.isNotEmpty()) {
                    resolvedSession.put("name", name)
                    resolvedSession.put("nameSource", "qldt_api_registration")
                }
            }
            val sync = NativeQldtWidgetSync(resolvedSession.toString())
            active = sync
            val remote = sync.run()
            if (ticket != epoch.get()) return cancelled(reply)
            when (remote) {
                is NativeQldtWidgetSync.Result.Failure ->
                    throw IllegalStateException(remote.message)
                is NativeQldtWidgetSync.Result.Success -> {
                    // Native verifier is the SAME authority used by existing sync.
                    // The raw envelope is sent separately ONLY for attendance.
                    val verified = NativeSemesterVerifier.verify(
                        remote.envelope, remote.registration, previous
                    )
                    if (ticket != epoch.get()) return cancelled(reply)
                    val route = JSONObject(remote.registration)
                        .optJSONObject("route")?.toString() ?: ""
                    val payload = mapOf(
                        "semester" to verified.semester,
                        "schedule" to verified.appSnapshot,
                        "registrationRoute" to route,
                        "attendanceEnvelope" to remote.envelope,
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
