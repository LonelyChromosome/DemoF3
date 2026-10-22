package vn.edu.phenikaa.better_phenikaa_schedule.findbike

import android.content.Context
import android.location.Location
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class VehicleStoreTest {
    private lateinit var context: Context
    private var now = 0L
    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("bpa_vehicle_demo_v1", 0).edit().clear().commit()
        context.getSharedPreferences("bpa_vehicle_TEST_v2", 0).edit().clear().commit()
        context.filesDir.resolve("vehicle_trace.csv").delete()
        now = System.currentTimeMillis()
    }
    private fun lesson(name: String = "Local class", start: Long = now + 3_600_000,
        end: Long = now + 7_200_000, kind: String = "LT") =
        mapOf<String, Any>("name" to name, "start" to start, "end" to end, "kind" to kind)
    @Test fun timetableCacheDoesNotEnableTracking() {
        VehicleStore.setWindows(context, listOf(lesson()))
        assertFalse(VehicleStore.isEnabled(context))
        assertFalse(VehicleStore.isTracking(context))
        assertEquals(1, VehicleStore.scheduleRows(context).size)
    }
    @Test fun excludesOnlineExpiredAndMalformedWindows() {
        VehicleStore.setWindows(context, listOf(lesson(), lesson(kind="ELEARNING"),
            lesson(name="English ELN01"), lesson(name="E-learning course"),
            lesson(end=now-1), lesson(start=now+8_000_000, end=now+7_000_000)))
        assertEquals(listOf("Local class"), VehicleStore.scheduleRows(context).map {it["name"]})
    }
    @Test fun queueRetainsOrderByStartAndFutureReadiness() {
        VehicleStore.setWindows(context, listOf(lesson("Later",now+4*3_600_000,now+5*3_600_000),lesson("Soon")))
        val rows=VehicleStore.scheduleRows(context)
        assertEquals(listOf("Soon","Later"),rows.map {it["name"]})
        assertEquals(true, rows[0]["available"])
        assertEquals(false, rows[1]["available"])
        assertTrue(VehicleStore.activeWindows(context, now))
        assertFalse(VehicleStore.activeWindows(context, now+6*3_600_000))
    }
    @Test fun parkedStateLocksQueueAndStopsTracking() {
        VehicleStore.setWindows(context,listOf(lesson()))
        VehicleStore.begin(context)
        VehicleStore.saveParked(context,20.962,105.748)
        assertTrue(VehicleStore.hasParked(context))
        assertFalse(VehicleStore.isTracking(context))
        assertEquals(false,VehicleStore.scheduleRows(context).single()["available"])
        assertEquals(20.962,VehicleStore.parkLat(context)!!,0.000001)
    }
    @Test fun manualRecoveryClearsOnlyVehicleStateAndTrace() {
        val shared=context.getSharedPreferences("FlutterSharedPreferences",0)
        shared.edit().putString("flutter.better_phenikaa_snapshot_v1","schedule untouched")
            .putString("attendance_cache","attendance untouched").commit()
        VehicleStore.enabled(context,true)
        VehicleStore.setWindows(context,listOf(lesson()))
        VehicleStore.begin(context)
        VehicleStore.append(context,Location("test").apply{latitude=20.962;longitude=105.748;time=now;accuracy=5f})
        VehicleStore.saveParked(context,20.962,105.748)
        VehicleStore.manualResetReal(context)
        assertFalse(VehicleStore.hasParked(context))
        assertFalse(VehicleStore.isTracking(context))
        assertTrue(VehicleStore.isEnabled(context))
        assertTrue(VehicleStore.route(context).isEmpty())
        assertEquals(1,VehicleStore.scheduleRows(context).size)
        assertEquals("schedule untouched",shared.getString("flutter.better_phenikaa_snapshot_v1",null))
        assertEquals("attendance untouched",shared.getString("attendance_cache",null))
    }
    @Test fun expiryDoesNotCreateParkingCoordinate() {
        VehicleStore.begin(context)
        VehicleStore.expireUnparkedSession(context)
        assertFalse(VehicleStore.isTracking(context))
        assertFalse(VehicleStore.hasParked(context))
    }
    @Test fun testStorageCannotOverwriteRealParking() {
        VehicleStore.saveParked(context,20.962,105.748)
        VehicleStore.saveParked(context,1.0,2.0,true)
        VehicleStore.rearmTest(context)
        assertTrue(VehicleStore.hasParked(context))
        assertEquals(20.962,VehicleStore.parkLat(context)!!,0.000001)
        assertFalse(VehicleStore.hasParked(context,true))
    }
}
