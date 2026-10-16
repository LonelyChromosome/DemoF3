package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import kotlin.math.abs

internal class WaterGravityBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : EventChannel.StreamHandler, SensorEventListener {
    private val manager = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val gravity = manager.getDefaultSensor(Sensor.TYPE_GRAVITY)
    private val accelerometer = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private var sink: EventChannel.EventSink? = null
    private var resumed = true
    private var initialized = false
    private var gravityTimestamp = 0L
    private val filtered = FloatArray(3)
    private val linear = FloatArray(3)
    private val channel = EventChannel(messenger, "better_phenikaa/water_gravity")
    init { channel.setStreamHandler(this) }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        if (gravity == null && accelerometer == null) {
            events.error("NO_GRAVITY", "Thiết bị không có cảm biến trọng lực", null)
        } else if (resumed) start()
    }

    private fun clearMotion() {
        initialized = false
        gravityTimestamp = 0L
        linear.fill(0f)
    }

    private fun start() {
        manager.unregisterListener(this)
        clearMotion()
        gravity?.let { manager.registerListener(this, it, 33333) }
        accelerometer?.let { manager.registerListener(this, it, 33333) }
    }

    override fun onCancel(arguments: Any?) {
        manager.unregisterListener(this)
        sink = null
        clearMotion()
    }

    fun resume() { resumed = true; if (sink != null) start() }
    fun pause() { resumed = false; manager.unregisterListener(this); clearMotion() }
    fun close() { pause(); sink = null; channel.setStreamHandler(null) }

    @Suppress("DEPRECATION")
    private fun screen(x: Float, y: Float): Pair<Double, Double> =
        when (activity.windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_90 -> Pair(y.toDouble(), x.toDouble())
            Surface.ROTATION_180 -> Pair(x.toDouble(), -y.toDouble())
            Surface.ROTATION_270 -> Pair(-y.toDouble(), -x.toDouble())
            else -> Pair(-x.toDouble(), y.toDouble())
        }

    override fun onSensorChanged(event: SensorEvent) {
        if (!resumed || sink == null || event.values.size < 3 ||
            (0..2).any { !event.values[it].isFinite() }) return
        if (event.sensor.type == Sensor.TYPE_GRAVITY) {
            for (i in 0..2) filtered[i] = event.values[i]
            gravityTimestamp = event.timestamp
            initialized = true
            if (accelerometer != null) return
        } else if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            if (gravity == null) {
                for (i in 0..2) filtered[i] = if (!initialized) event.values[i]
                    else filtered[i] * .88f + event.values[i] * .12f
                initialized = true
                gravityTimestamp = event.timestamp
            }
            if (!initialized) return
            // Do not subtract a pre-suspension/stale gravity sample: that would
            // create a fictitious shake when returning with a different pose.
            if (abs(event.timestamp - gravityTimestamp) <= 100_000_000L) {
                for (i in 0..2) linear[i] = event.values[i] - filtered[i]
            } else linear.fill(0f)
        } else return
        val g = screen(filtered[0], filtered[1])
        val a = screen(linear[0], linear[1])
        sink?.success(listOf(g.first, g.second, -a.first, -a.second, filtered[2].toDouble()))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
}
