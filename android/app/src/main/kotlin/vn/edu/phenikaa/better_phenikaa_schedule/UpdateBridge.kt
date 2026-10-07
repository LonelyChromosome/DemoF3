package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.net.Uri
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.URL
import java.security.KeyStore
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.net.ssl.HttpsURLConnection

/** The UID never crosses the Flutter bridge; only accepted/wrong is reported. */
internal class UpdateBridge(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "better_phenikaa/update")
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val busy = AtomicBoolean(false)
    private val cancelled = AtomicBoolean(false)
    private val nfc = NfcAdapter.getDefaultAdapter(activity)
    @Volatile private var reading = false
    private val uidStore = BoundCardStore(activity)

    init {
        UpdateInstaller.cleanupStale(activity)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "versionCode" -> result.success(installedVersionCode())
                "startCard" -> {
                    if (busy.get()) result.error("busy", "Đang cập nhật.", null)
                    else if (nfc == null || !nfc.isEnabled) result.error("nfc_unavailable", "Hãy bật NFC để đọc thẻ.", null)
                    else {
                        reading = true
                        enableReader()
                        result.success(null)
                    }
                }
                "stopCard" -> { stopReader(); result.success(null) }
                "cancel" -> { cancelled.set(true); stopReader(); result.success(null) }
                "canInstall" -> result.success(Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls())
                "installStatus" -> result.success(UpdateInstaller.takeStatus(activity))
                "installSettings" -> {
                    if (Build.VERSION.SDK_INT >= 26) {
                        activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:${activity.packageName}")))
                    }
                    result.success(null)
                }
                "downloadAndInstall" -> {
                    if (!busy.compareAndSet(false, true)) {
                        result.error("busy", "Đang cập nhật.", null)
                        return@setMethodCallHandler
                    }
                    stopReader()
                    cancelled.set(false)
                    val url = call.argument<String>("url")
                    val sha = call.argument<String>("sha256")
                    val size = call.argument<Number>("size")?.toLong()
                    val version = call.argument<Number>("versionCode")?.toLong()
                    if (url == null || sha == null || size == null || version == null ||
                        !sha.matches(Regex("[0-9a-fA-F]{64}")) || size !in 1..300_000_000L ||
                        version <= installedVersionCode() || !url.startsWith("https://")) {
                        busy.set(false)
                        result.error("invalid_metadata", "Thông tin cập nhật không hợp lệ.", null)
                        return@setMethodCallHandler
                    }
                    if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                        busy.set(false)
                        result.error("permission_required", "Android cần quyền cho phép cài đặt.", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val apk = download(url, sha, size)
                            if (cancelled.get()) throw UpdateCancelled()
                            event("verifying")
                            UpdateInstaller.verifyCandidate(activity, apk, version)
                            if (cancelled.get()) throw UpdateCancelled()
                            event("preparing")
                            UpdateInstaller.install(activity, apk, version)
                            main.post { result.success(null) }
                        } catch (e: Exception) {
                            UpdateInstaller.clearTemp(activity)
                            main.post { result.error(if (e is UpdateCancelled) "cancelled" else "update_failed",
                                if (e is UpdateCancelled) "Đã hủy cập nhật." else "Không thể tải hoặc xác minh bản cập nhật.", null) }
                        } finally { busy.set(false) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onResume() { if (reading) enableReader() }
    fun onPause() { if (reading) nfc?.disableReaderMode(activity) }
    fun close() { stopReader(); cancelled.set(true); executor.shutdownNow(); channel.setMethodCallHandler(null) }

    private fun enableReader() {
        nfc?.enableReaderMode(activity, { tag: Tag ->
            if (!reading) return@enableReaderMode
            val normalized = BoundCardStore.normalize(tag.id)
            if (normalized.isEmpty()) return@enableReaderMode
            // Reader callbacks can run more than once. The first readable tag wins on a fresh install.
            try {
                val accepted = uidStore.matchesOrBind(normalized)
                if (accepted) stopReader()
                event(if (accepted) "cardAccepted" else "wrongCard")
            } catch (_: Exception) {
                stopReader()
                event("cardError")
            }
        }, NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK, null)
    }

    private fun stopReader() {
        if (reading) {
            reading = false
            main.post { nfc?.disableReaderMode(activity) }
        }
    }

    private fun event(type: String, bytes: Long = 0, total: Long = 0) {
        main.post { channel.invokeMethod("event", mapOf("type" to type, "bytes" to bytes, "total" to total)) }
    }

    private fun installedVersionCode(): Long {
        val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
        return if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()
    }

    private fun download(url: String, expectedSha: String, expectedSize: Long): File {
        val root = UpdateInstaller.tempDir(activity)
        root.mkdirs()
        val file = File(root, "candidate.apk")
        file.delete()
        val connection = URL(url).openConnection() as HttpsURLConnection
        connection.connectTimeout = 10000
        connection.readTimeout = 20000
        connection.instanceFollowRedirects = false
        try {
            if (connection.responseCode != 200 || connection.contentLengthLong > expectedSize) {
                throw IllegalStateException("Unexpected download response")
            }
            val digest = MessageDigest.getInstance("SHA-256")
            var count = 0L
            connection.inputStream.use { input ->
                file.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        if (cancelled.get()) throw UpdateCancelled()
                        val read = input.read(buffer)
                        if (read < 0) break
                        count += read
                        if (count > expectedSize) throw IllegalStateException("Size exceeded")
                        output.write(buffer, 0, read)
                        digest.update(buffer, 0, read)
                        event("downloading", count, expectedSize)
                    }
                    output.flush()
                }
            }
            if (count != expectedSize || !DigestRules.matches(digest.digest(), expectedSha)) {
                throw IllegalStateException("APK digest mismatch")
            }
            return file
        } catch (e: Exception) { file.delete(); throw e }
        finally { connection.disconnect() }
    }

    private class UpdateCancelled : Exception()
}

internal object DigestRules {
    fun matches(actual: ByteArray, expectedHex: String): Boolean {
        if (!expectedHex.matches(Regex("[0-9a-fA-F]{64}"))) return false
        val expected = ByteArray(32) { i -> expectedHex.substring(i * 2, i * 2 + 2).toInt(16).toByte() }
        return MessageDigest.isEqual(actual, expected)
    }
}

/** Private AES-GCM ciphertext; Keystore key is non-exportable and app data is not backed up. */
internal class BoundCardStore(context: Context) {
    private val prefs = context.getSharedPreferences("update_bound_card", Context.MODE_PRIVATE)

    @Synchronized fun matchesOrBind(uid: String): Boolean {
        val saved = prefs.getString("encrypted_uid", null)
        if (saved != null) {
            val expected = decrypt(saved)
            return matches(expected, uid)
        }
        // commit is synchronous: a second callback cannot race the first binding.
        if (!prefs.edit().putString("encrypted_uid", encrypt(uid)).commit()) {
            throw IllegalStateException("Cannot save card binding")
        }
        return true
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("update_card_v1", null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder("update_card_v1", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
            generateKey()
        }
    }

    private fun encrypt(uid: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        return Base64.encodeToString(cipher.iv + cipher.doFinal(uid.toByteArray(Charsets.US_ASCII)), Base64.NO_WRAP)
    }

    private fun decrypt(value: String): String {
        val raw = Base64.decode(value, Base64.NO_WRAP)
        require(raw.size > 28)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, raw.copyOfRange(0, 12)))
        return String(cipher.doFinal(raw.copyOfRange(12, raw.size)), Charsets.US_ASCII)
    }

    companion object {
        // Android Tag.id bytes are kept in the order returned by the platform.
        fun normalize(id: ByteArray): String = id.joinToString("") { "%02X".format(it.toInt() and 0xff) }
        fun matches(expected: String, observed: String): Boolean = MessageDigest.isEqual(
            expected.toByteArray(Charsets.US_ASCII), observed.toByteArray(Charsets.US_ASCII))
    }
}
