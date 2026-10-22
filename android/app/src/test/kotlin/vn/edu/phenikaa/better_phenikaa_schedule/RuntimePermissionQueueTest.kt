package vn.edu.phenikaa.better_phenikaa_schedule

import android.Manifest
import android.app.Activity
import android.app.Application
import android.os.Looper
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[35])
class RuntimePermissionQueueTest {
    @Test fun kdaAndFindBikeDialogsAreSerializedEvenAfterDenial() {
        val activity=Robolectric.buildActivity(Activity::class.java).setup().get()
        shadowOf(activity.application as Application).denyPermissions(
            Manifest.permission.RECORD_AUDIO,Manifest.permission.ACTIVITY_RECOGNITION)
        val queue=RuntimePermissionQueue(activity)
        var audioDone=false;var motionDone=false
        queue.request(8463,arrayOf(Manifest.permission.RECORD_AUDIO)){audioDone=true}
        queue.request(7419,arrayOf(Manifest.permission.ACTIVITY_RECOGNITION)){motionDone=true}
        assertEquals(8463,shadowOf(activity).lastRequestedPermission.requestCode)
        assertFalse(audioDone);assertFalse(motionDone)
        queue.result(7419) // unrelated callback must not complete the microphone request
        assertFalse(audioDone)
        queue.result(8463)
        shadowOf(Looper.getMainLooper()).idle()
        assertTrue(audioDone)
        assertEquals(7419,shadowOf(activity).lastRequestedPermission.requestCode)
        queue.result(7419)
        assertTrue(motionDone)
        queue.close()
    }
    @Test fun fineAndCoarseRemainTogetherWhenUpgradingApproximateLocation() {
        val activity=Robolectric.buildActivity(Activity::class.java).setup().get()
        shadowOf(activity.application as Application).grantPermissions(Manifest.permission.ACCESS_COARSE_LOCATION)
        shadowOf(activity.application as Application).denyPermissions(Manifest.permission.ACCESS_FINE_LOCATION)
        val queue=RuntimePermissionQueue(activity)
        queue.request(7419,arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION)){}
        assertArrayEquals(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION),
            shadowOf(activity).lastRequestedPermission.requestedPermissions)
        queue.close()
    }
}
