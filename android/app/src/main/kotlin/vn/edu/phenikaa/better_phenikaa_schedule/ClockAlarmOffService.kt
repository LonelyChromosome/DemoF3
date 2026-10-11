package vn.edu.phenikaa.better_phenikaa_schedule

import android.accessibilityservice.AccessibilityService
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import java.util.Locale

/** One-shot, explicitly user-enabled Clock-only OFF automation. */
class ClockAlarmOffService : AccessibilityService() {
    private data class Target(
        val name: String, val hour: Int, val minute: Int, val pkg: String,
        val started: Long = SystemClock.elapsedRealtime()
    )

    companion object {
        @Volatile private var active: ClockAlarmOffService? = null
        fun isReady(): Boolean = active != null
        fun begin(name: String, hour: Int, minute: Int, pkg: String): Boolean {
            val service = active ?: return false
            if (name.isBlank() || pkg.isBlank() || pkg == "android" ||
                hour !in 0..23 || minute !in 0..59) return false
            service.start(Target(name, hour, minute, pkg))
            return true
        }
        fun abort() { active?.finish() }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var target: Target? = null
    private var wasInClock = false
    private var scheduled = false
    private var direction = 1
    private var forward = 0
    private var backward = 0
    private var lastSignature = ""
    private var stalled = 0

    override fun onServiceConnected() {
        super.onServiceConnected()
        active = this
    }

    override fun onDestroy() {
        finish()
        if (active === this) active = null
        super.onDestroy()
    }

    override fun onInterrupt() { finish() }

    private fun start(value: Target) {
        finish()
        target = value
        schedule(500)
    }

    private fun finish() {
        target = null
        handler.removeCallbacksAndMessages(null)
        scheduled = false
        wasInClock = false
        direction = 1
        forward = 0
        backward = 0
        stalled = 0
        lastSignature = ""
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val t = target ?: return
        if (SystemClock.elapsedRealtime() - t.started > 25000) { fail(); return }
        if (event?.packageName?.toString() != t.pkg) {
            if (wasInClock && event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED)
                finish() // User left Clock; do not interact with other apps.
            return
        }
        wasInClock = true
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> schedule(240)
        }
    }

    private fun schedule(ms: Long) {
        if (scheduled || target == null) return
        scheduled = true
        handler.postDelayed({
            scheduled = false
            examine()
        }, ms)
    }

    private fun examine() {
        val t = target ?: return
        if (SystemClock.elapsedRealtime() - t.started > 25000) { fail(); return }
        val root = rootInActiveWindow ?: run { schedule(350); return }
        if (root.packageName?.toString() != t.pkg) {
            if (!wasInClock) schedule(350)
            return
        }
        wasInClock = true
        val matches = findMatchingSwitches(root, t)
        if (matches.size > 1) { fail(); return }
        if (matches.size == 1) {
            val toggle = matches.single()
            if (!toggle.isCheckable || !toggle.isEnabled) { fail(); return }
            val shouldClick = toggle.isChecked
            finish() // Disarm first: never toggle an alarm twice.
            if (shouldClick && !toggle.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                Toast.makeText(this, "Không thể gạt báo thức trong Đồng hồ.", Toast.LENGTH_LONG).show()
            }
            return
        }

        val signature = flatten(root, 180).map(::textOf)
            .filter { it.isNotBlank() }.take(45).joinToString("|")
        stalled = if (signature == lastSignature) stalled + 1 else 0
        lastSignature = signature
        val list = flatten(root, 350).filter { it.isScrollable }.maxByOrNull {
            val r = Rect()
            it.getBoundsInScreen(r)
            r.width() * r.height()
        } ?: run { fail(); return }

        if (stalled >= 2 || forward >= 18) {
            if (direction > 0) {
                direction = -1
                stalled = 0
            } else { fail(); return }
        }
        if (backward >= 18) { fail(); return }
        val action = if (direction > 0) AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
                     else AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
        if (list.performAction(action)) {
            if (direction > 0) forward++ else backward++
            schedule(450)
        } else if (direction > 0) {
            direction = -1
            schedule(230)
        } else fail()
    }

    // Match TIME first, then the exact course name and a single checkable
    // switch inside the same small alarm row. Never tap screen coordinates.
    private fun findMatchingSwitches(
        root: AccessibilityNodeInfo, target: Target
    ): List<AccessibilityNodeInfo> {
        val timed = flatten(root, 550).filter {
            containsTime(textOf(it), target.hour, target.minute)
        }
        val unique = linkedMapOf<String, AccessibilityNodeInfo>()
        val maxRowHeight = resources.displayMetrics.heightPixels * 0.42
        for (timeNode in timed) {
            var parent: AccessibilityNodeInfo? = timeNode
            repeat(7) {
                val row = parent ?: return@repeat
                val bounds = Rect().also { row.getBoundsInScreen(it) }
                if (bounds.height() > maxRowHeight) return@repeat
                val nodes = flatten(row, 100)
                val named = nodes.any { containsName(textOf(it), target.name) }
                val switches = nodes.filter {
                    it.isCheckable && (
                        it.className?.toString()?.contains("Switch", true) == true ||
                        it.viewIdResourceName?.contains("switch", true) == true ||
                        it.contentDescription?.toString()?.contains("công tắc", true) == true
                    )
                }
                if (named && switches.size == 1) {
                    val toggle = switches.single()
                    val b = Rect().also { toggle.getBoundsInScreen(it) }
                    val key = listOf(b.left, b.top, b.right, b.bottom).joinToString(":")
                    unique[key] = toggle
                    return@repeat
                }
                parent = row.parent
            }
        }
        return unique.values.toList()
    }

    private fun containsName(raw: String, label: String): Boolean {
        val text = raw.lowercase(Locale.ROOT).replace(Regex("\\s+"), " ").trim()
        val name = label.lowercase(Locale.ROOT).replace(Regex("\\s+"), " ").trim()
        return text == name || (text.contains(name) && text.length <= name.length + 45)
    }

    private fun containsTime(raw: String, hour: Int, minute: Int): Boolean {
        if (raw.isBlank()) return false
        val pm = Regex("(?i)\\bpm\\b|chiều|tối|오후|下午").containsMatchIn(raw)
        val am = Regex("(?i)\\bam\\b|sáng|오전|上午").containsMatchIn(raw)
        return Regex("(?<!\\d)(\\d{1,2})[:.](\\d{2})(?!\\d)")
            .findAll(raw).any {
                val h = it.groupValues[1].toIntOrNull() ?: return@any false
                val m = it.groupValues[2].toIntOrNull() ?: return@any false
                if (m != minute) return@any false
                if (am || pm) (h % 12) + (if (pm) 12 else 0) == hour
                else h == hour // Never guess an ambiguous 12-hour time.
            }
    }

    private fun textOf(node: AccessibilityNodeInfo): String =
        listOfNotNull(node.text?.toString(), node.contentDescription?.toString())
            .joinToString(" ").trim()

    private fun flatten(root: AccessibilityNodeInfo, max: Int): List<AccessibilityNodeInfo> {
        val result = ArrayList<AccessibilityNodeInfo>()
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        while (queue.isNotEmpty() && result.size < max) {
            val n = queue.removeFirst()
            result.add(n)
            for (i in 0 until n.childCount) n.getChild(i)?.let(queue::addLast)
        }
        return result
    }

    private fun fail() {
        finish()
        Toast.makeText(this, "Không tìm thấy đúng báo thức; chưa gạt công tắc.", Toast.LENGTH_LONG).show()
    }
}
