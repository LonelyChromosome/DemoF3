package vn.edu.phenikaa.better_phenikaa_schedule.findbike

import android.Manifest
import android.app.Application
import android.content.ComponentName
import android.provider.Settings
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class VehiclePermissionsTest {
    private val app: Application get() = RuntimeEnvironment.getApplication()
    @Before fun setup() {
        app.getSharedPreferences("bpa_vehicle_demo_v1", 0).edit().clear().commit()
        shadowOf(app).denyPermissions(Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACTIVITY_RECOGNITION,
            Manifest.permission.POST_NOTIFICATIONS)
    }
    @Test fun requestDoesNotRequireEnabledOrTimetableAndDoesNotCombineBackground() {
        assertFalse(VehicleStore.isEnabled(app))
        val request=VehiclePermissions.runtime(app).toList()
        assertTrue(request.containsAll(listOf(Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACTIVITY_RECOGNITION,
            Manifest.permission.POST_NOTIFICATIONS)))
        assertFalse(request.contains(Manifest.permission.ACCESS_BACKGROUND_LOCATION))
    }
    @Test fun approximateGrantStillRequestsPreciseAndKeepsCoarseInSameRequest() {
        shadowOf(app).grantPermissions(Manifest.permission.ACCESS_COARSE_LOCATION)
        assertTrue(VehiclePermissions.runtime(app).contains(Manifest.permission.ACCESS_FINE_LOCATION))
        assertTrue(VehiclePermissions.runtime(app).contains(Manifest.permission.ACCESS_COARSE_LOCATION))
        assertEquals(false,VehicleStore.snapshot(app)["location"])
    }
    @Test fun permissionStateAndSeenFlagDoNotEnableGps() {
        VehiclePermissions.markSeen(app)
        assertEquals(true,VehicleStore.snapshot(app)["setupSeen"])
        assertFalse(VehicleStore.isEnabled(app))
        shadowOf(app).grantPermissions(Manifest.permission.ACTIVITY_RECOGNITION,
            Manifest.permission.POST_NOTIFICATIONS)
        assertEquals(true,VehicleStore.snapshot(app)["motion"])
        assertEquals(true,VehicleStore.snapshot(app)["notifications"])
        assertFalse(VehiclePermissions.runtime(app).contains(Manifest.permission.ACTIVITY_RECOGNITION))
    }
    @Test fun listenerLinkTargetsThisAppsActualComponent() {
        val intent=VehiclePermissions.notificationSettings(app)
        assertEquals(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS,intent.action)
        assertEquals(ComponentName(app,VehicleExitNotificationListener::class.java).flattenToString(),
            intent.getStringExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME))
        assertEquals("package:"+app.packageName,VehiclePermissions.appSettings(app).dataString)
    }
    @Test @Config(sdk=[28]) fun olderAndroidDoesNotAskForNewerRuntimeGroups() {
        val request=VehiclePermissions.runtime(app)
        assertFalse(request.contains(Manifest.permission.ACTIVITY_RECOGNITION))
        assertFalse(request.contains(Manifest.permission.POST_NOTIFICATIONS))
        assertEquals(true,VehiclePermissions.snapshot(app)["motion"])
        assertEquals(true,VehiclePermissions.snapshot(app)["notifications"])
    }
}
