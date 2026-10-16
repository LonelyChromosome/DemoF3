package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import java.nio.ByteBuffer
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowSensor

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WaterGravityLifecycleTest {
    private val messenger = object : BinaryMessenger {
        override fun send(channel: String, message: ByteBuffer?) = Unit
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) = Unit
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) = Unit
    }
    private class Sink : EventChannel.EventSink {
        val samples = mutableListOf<List<Double>>()
        override fun success(event: Any?) {
            @Suppress("UNCHECKED_CAST") samples.add(event as List<Double>)
        }
        override fun error(code: String, message: String?, details: Any?) = error("Unexpected sensor error: $code")
        override fun endOfStream() = Unit
    }
    private fun event(sensor: Sensor, time: Long, x: Float, y: Float, z: Float): SensorEvent {
        val constructor = SensorEvent::class.java.getDeclaredConstructor(Int::class.javaPrimitiveType)
        constructor.isAccessible = true
        return constructor.newInstance(3).also {
            it.sensor = sensor; it.timestamp = time
            it.values[0] = x; it.values[1] = y; it.values[2] = z
        }
    }
    private fun setup(test: (WaterGravityBridge, Sink, Sensor, Sensor) -> Unit) {
        val controller = Robolectric.buildActivity(Activity::class.java).setup()
        val activity = controller.get()
        val manager = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val g = ShadowSensor.newInstance(Sensor.TYPE_GRAVITY)
        val a = ShadowSensor.newInstance(Sensor.TYPE_ACCELEROMETER)
        shadowOf(manager).addSensor(g); shadowOf(manager).addSensor(a)
        val bridge = WaterGravityBridge(activity, messenger)
        try {
            val sink = Sink(); bridge.onListen(null, sink)
            test(bridge, sink, g, a)
        } finally { bridge.close(); controller.pause().stop().destroy() }
    }
    @Test fun accelerationBeforeFreshGravityCannotReplayAfterResume() = setup { bridge, sink, g, a ->
        bridge.onSensorChanged(event(g, 1_000_000_000, 0f, 9.81f, 0f))
        bridge.onSensorChanged(event(a, 1_010_000_000, 4f, 9.81f, 0f))
        assertEquals(1, sink.samples.size)
        bridge.pause(); bridge.resume()
        bridge.onSensorChanged(event(a, 3_000_000_000, 0f, -9.81f, 0f))
        assertEquals(1, sink.samples.size)
        bridge.onSensorChanged(event(g, 3_010_000_000, 0f, -9.81f, 0f))
        bridge.onSensorChanged(event(a, 3_020_000_000, 0f, -9.81f, 0f))
        val sample = sink.samples.last()
        assertEquals(-9.81, sample[1], .001)
        assertEquals(0.0, sample[2], .001); assertEquals(0.0, sample[3], .001)
    }
    @Test fun staleGravityIsNotSubtractedAsAFalseShake() = setup { bridge, sink, g, a ->
        bridge.onSensorChanged(event(g, 1_000_000_000, 0f, 9.81f, 0f))
        bridge.onSensorChanged(event(a, 2_000_000_000, 0f, -9.81f, 0f))
        assertEquals(0.0, sink.samples.last()[3], .001)
    }
    @Test fun cancellationAndRelistenResetGravityAsWellAsAcceleration() = setup { bridge, sink, g, a ->
        bridge.onSensorChanged(event(g, 1_000_000_000, 0f, 9.81f, 0f))
        bridge.onSensorChanged(event(a, 1_010_000_000, 0f, 9.81f, 0f))
        bridge.onCancel(null); bridge.onListen(null, sink)
        bridge.onSensorChanged(event(a, 1_020_000_000, 8f, -9.81f, 0f))
        assertEquals(1, sink.samples.size)
    }
    @Test fun backgroundDoesNotEmitAndInvalidSamplesAreIgnored() = setup { bridge, sink, g, a ->
        bridge.onSensorChanged(event(g, 1_000_000_000, Float.NaN, 9.81f, 0f))
        bridge.onSensorChanged(event(a, 1_010_000_000, 0f, 9.81f, 0f))
        assertTrue(sink.samples.isEmpty())
        bridge.pause()
        bridge.onSensorChanged(event(g, 1_020_000_000, 0f, 9.81f, 0f))
        bridge.onSensorChanged(event(a, 1_030_000_000, 0f, 9.81f, 0f))
        assertTrue(sink.samples.isEmpty())
    }
}
