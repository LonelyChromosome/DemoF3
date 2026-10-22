package vn.edu.phenikaa.better_phenikaa_schedule
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
@RunWith(RobolectricTestRunner::class)
@Config(sdk=[34])
class KdaFirestarterTest {
 @Test fun sequenceContinuesPastFour(){assertEquals(listOf(0,1,2,3,0,1,2,3,0),(0..8).map(KdaWidgetImages::smallIndex))}
 @Test fun reloadHasIndependentPersistentState(){val c=RuntimeEnvironment.getApplication();val other=KdaWidgetImages.current(c,"widget2",11);var old=KdaWidgetImages.current(c,"large",11);repeat(40){val next=KdaWidgetImages.advance(c,"large",11);assertNotEquals(old,next);assertEquals(other,KdaWidgetImages.current(c,"widget2",11));old=next}}
 @Test fun silenceAndBackgroundAreIdle(){assertEquals(3000L,KdaPlaybackPolicy.HOLD_MS);assertTrue(KdaPlaybackPolicy.fftBands(ByteArray(1024),44100.0).all{it==0.0});assertFalse(KdaPlaybackPolicy.shouldPlay(true,false,true,true));assertFalse(KdaPlaybackPolicy.shouldPlay(true,true,false,false));assertTrue(KdaPlaybackPolicy.shouldPlay(true,true,true,false))}
 @Test fun originalImagesDecode(){val c=RuntimeEnvironment.getApplication();for(i in 0..3){val b=KdaWidgetImages.largeBitmap(c,360,220,i);assertEquals(360,b.width);b.recycle();KdaWidgetImages.widget2Bitmap(c,400,200,i).recycle()}}
 @Test @GraphicsMode(GraphicsMode.Mode.NATIVE)
 fun widget2BackgroundUsesTheSelectedPhotoRatherThanSolidColor(){
  val c=RuntimeEnvironment.getApplication()
  val first=KdaWidgetImages.widget2Bitmap(c,400,200,0)
  val second=KdaWidgetImages.widget2Bitmap(c,400,200,3)
  try{
   // Sample vertically inside the left timetable pane: a horizontal tint alone
   // cannot pass this check, and the sharp photo pane is outside the sample.
   val firstColors=(30..170 step 4).map{first.getPixel(90,it)}
   val secondColors=(30..170 step 4).map{second.getPixel(90,it)}
   assertTrue(firstColors.toSet().size>8)
   assertNotEquals(firstColors,secondColors)
  }finally{first.recycle();second.recycle()}
 }
}
