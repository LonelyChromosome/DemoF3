package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Activity
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper

/** One system permission dialog at a time across KDA and Find Bike. */
internal class RuntimePermissionQueue(private val activity: Activity) {
    private data class Request(val code: Int, val permissions: Array<String>, val done: () -> Unit)
    private val pending = ArrayDeque<Request>()
    private var active: Request? = null
    private var closed = false
    fun request(code: Int, permissions: Array<String>, done: () -> Unit) {
        if (closed) { done(); return }
        pending.addLast(Request(code, permissions, done))
        next()
    }
    private fun next() {
        if (closed || active != null || pending.isEmpty()) return
        val request = pending.removeFirst()
        val allGranted = request.permissions.all {
            activity.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }
        if (allGranted) { request.done(); next(); return }
        active = request
        try { activity.requestPermissions(request.permissions, request.code) }
        catch (error: Exception) { active = null; request.done(); next() }
    }
    fun result(code: Int) {
        val request = active ?: return
        if (request.code != code) return
        active = null
        request.done()
        // Let Android dismiss its previous dialog before showing another one.
        Handler(Looper.getMainLooper()).post { next() }
    }
    fun close() {
        closed = true
        val outstanding = listOfNotNull(active) + pending.toList()
        active = null
        pending.clear()
        outstanding.forEach { it.done() }
    }
}
