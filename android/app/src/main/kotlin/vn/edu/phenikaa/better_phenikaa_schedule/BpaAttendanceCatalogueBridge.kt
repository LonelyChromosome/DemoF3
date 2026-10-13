package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors

/**
 * Optional supplementary course-catalogue lookup for official LT allocations.
 * Runs AFTER the authoritative QLĐT sync returns; never writes a schedule,
 * touches session state or blocks main-thread/login/sync callbacks.
 */
internal class BpaAttendanceCatalogueBridge(context: Context, engine: FlutterEngine) {
    private val app = context.applicationContext
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "load") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val programId = (call.argument<String>("programId") ?: "").trim()
                if (!Regex("^[A-Fa-f0-9]{32}$").matches(programId)) {
                    result.success(emptyList<Map<String, String>>())
                    return@setMethodCallHandler
                }
                executor.execute {
                    val rows = runCatching { load(programId) }.getOrElse { emptyList() }
                    main.post { result.success(rows) }
                }
            }
    }

    private fun load(programId: String): List<Map<String, String>> {
        val prefs = app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val sessionText = prefs.getString("flutter.better_phenikaa_qldt_native_session_v1", null)
            ?: return emptyList()
        val routeText = prefs.getString("flutter.better_phenikaa_qldt_registration_route_v1", null)
            ?: return emptyList()
        val session = JSONObject(sessionText)
        val route = JSONObject(routeText)
        val userId = session.optString("userId")
        if (userId.isBlank() || userId != route.optString("userId")) return emptyList()
        val token = session.optString("tokenJWT")
        val iM = session.optString("iM")
        if (token.isBlank() || iM.isBlank()) return emptyList()

        val payload = JSONObject()
            .put("action", ACTION)
            .put("func", FUNC)
            .put("iM", iM)
            .put("strQLSV_NguoiHoc_Id", userId)
            .put("strNguoiThucHien_Id", userId)
            .put("strChucNang_Id", session.optString("strChucNangId"))
            .put("strVaiTroDangNhap_Id", session.optString("appId"))
            .put("strChucNangHeThong_Id", session.optString("strChucNangId"))
            .put("pageIndex", 1)
            .put("pageSize", 100000000)
            .put("strDaoTao_ChuongTrinh_Id", programId)
            .put("strDaoTao_HocPhan_Id", "")
            .put("strDaoTao_ThoiGian_KH_Id", "")
            .put("strDaoTao_ThoiGian_TT_Id", "")
            .put("strPhanCongPhamViDamNhiem_Id", "")
            .put("strThuocTinhHocPhan_Id", "")
            .put("strTuKhoa", "")
        val key = ACTION.substringAfter("/")
        val url = URL(ROOT + "/kehoachchuongtrinhapi/api/" + ACTION)
        val connection = url.openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 4000
            connection.readTimeout = 4000
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Accept", "application/json, text/javascript, */*; q=0.01")
            connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
            val cookie = session.optString("cookie")
            if (cookie.isNotBlank()) connection.setRequestProperty("Cookie", cookie)
            val body = "A=" + URLEncoder.encode(
                encode(payload.toString(), key), StandardCharsets.UTF_8.name()
            )
            connection.outputStream.use {
                it.write(body.toByteArray(StandardCharsets.UTF_8))
            }
            if (connection.responseCode != 200) return emptyList()
            val text = connection.inputStream.bufferedReader(StandardCharsets.UTF_8)
                .use { it.readText() }
            val response = JSONObject(text)
            if (!response.optBoolean("Success", false)) return emptyList()
            val encrypted = response.optJSONObject("Data")?.optString("B").orEmpty()
            if (encrypted.isNotEmpty()) {
                response.put("Data", JSONTokener(decode(encrypted, iM)).nextValue())
            }
            val records = response.optJSONArray("Data") ?: return emptyList()
            return buildList {
                for (index in 0 until records.length()) {
                    val record = records.optJSONObject(index) ?: continue
                    val name = record.optString("DAOTAO_HOCPHAN_TEN").trim()
                    val allocation = record.optString("THONGTINPHANBOTIETHOC").trim()
                    if (name.isNotEmpty() && allocation.isNotEmpty()) {
                        add(mapOf("DAOTAO_HOCPHAN_TEN" to name,
                            "THONGTINPHANBOTIETHOC" to allocation))
                    }
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun encode(source: String, key: String): String {
        val text = buildString {
            source.forEachIndexed { index, ch ->
                append((ch.code xor key[index % key.length].code).toChar())
            }
        }
        return Base64.encodeToString(text.toByteArray(StandardCharsets.UTF_8), Base64.NO_WRAP)
    }

    private fun decode(source: String, key: String): String {
        val cipher = String(Base64.decode(source, Base64.DEFAULT), StandardCharsets.UTF_8)
        return buildString {
            cipher.forEachIndexed { index, ch ->
                append((ch.code xor key[index % key.length].code).toChar())
            }
        }
    }

    private companion object {
        const val CHANNEL = "better_phenikaa/attendance_catalogue"
        const val ROOT = "https://qldtbeta.phenikaa-uni.edu.vn"
        const val ACTION = "KHCT_ThongTin_MH/DSA4BRIKEh4FIC4VIC4eCS4iESkgLx4CFQPP"
        const val FUNC = "pkg_kehoach_thongtin.LayDSKS_DaoTao_HocPhan_CT"
    }
}
