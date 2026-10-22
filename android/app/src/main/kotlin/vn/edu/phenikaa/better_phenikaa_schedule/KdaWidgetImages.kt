package vn.edu.phenikaa.better_phenikaa_schedule
import android.content.Context
import android.graphics.*
import android.util.LruCache
import kotlin.random.Random
/** Static bitmap backgrounds: no video decoder and no audio subscription. */
internal object KdaWidgetImages {
 const val THEME="kda_firestarter"
 private const val PREFS="bpa_kda_widget_images_v1"
 private val cache=object:LruCache<Int,Bitmap>(8*1024*1024){override fun sizeOf(key:Int,value:Bitmap)=value.byteCount}
 fun enabled(c:Context)=NativeWidgetPalette.read(c).key==THEME
 fun smallIndex(position:Int)=Math.floorMod(position,4)
 fun nextIndex(current:Int,offset:Int)=(smallIndex(current)+1+Math.floorMod(offset,3))%4
 @Synchronized fun current(c:Context,surface:String,id:Int):Int{val p=c.getSharedPreferences(PREFS,Context.MODE_PRIVATE);val key="$surface.$id";if(!p.contains(key))p.edit().putInt(key,Random.nextInt(4)).apply();return p.getInt(key,0).coerceIn(0,3)}
 @Synchronized fun advance(c:Context,surface:String,id:Int):Int{val next=nextIndex(current(c,surface,id),Random.nextInt(3));c.getSharedPreferences(PREFS,Context.MODE_PRIVATE).edit().putInt("$surface.$id",next).apply();return next}
 private fun image(c:Context,index:Int):Bitmap{val i=smallIndex(index);return cache.get(i)?:c.assets.open("flutter_assets/assets/kda/character_${i+1}.jpg").use{requireNotNull(BitmapFactory.decodeStream(it))}.also{cache.put(i,it)}}
 private fun cover(canvas:Canvas,b:Bitmap,rect:RectF){val scale=maxOf(rect.width()/b.width,rect.height()/b.height);val w=b.width*scale;val h=b.height*scale;val save=canvas.save();canvas.clipRect(rect);canvas.drawBitmap(b,null,RectF(rect.centerX()-w/2,rect.centerY()-h/2,rect.centerX()+w/2,rect.centerY()+h/2),Paint(Paint.FILTER_BITMAP_FLAG));canvas.restoreToCount(save)}
 fun drawSmall(c:Context,canvas:Canvas,width:Int,height:Int,index:Int){val bounds=RectF(0f,0f,width.toFloat(),height.toFloat());cover(canvas,image(c,index),bounds);canvas.drawRect(bounds,Paint().apply{shader=LinearGradient(0f,0f,width.toFloat(),height.toFloat(),intArrayOf(0xD9080410.toInt(),0x9E10091B.toInt(),0x80080410.toInt()),null,Shader.TileMode.CLAMP)})}
 fun largeBitmap(c:Context,width:Int,height:Int,index:Int):Bitmap{val b=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888);val canvas=Canvas(b);canvas.clipRoundRect(RectF(0f,0f,width.toFloat(),height.toFloat()),height*.06f,height*.06f);drawSmall(c,canvas,width,height,index);return b}
 fun widget2Bitmap(c:Context,width:Int,height:Int,index:Int):Bitmap{val b=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888);val canvas=Canvas(b);canvas.clipRoundRect(RectF(0f,0f,width.toFloat(),height.toFloat()),height*.09f,height*.09f);canvas.drawColor(0xF0100819.toInt());val inset=maxOf(7f,height*.055f);val rect=RectF(width*.69f,inset,width-inset,height-inset);val save=canvas.save();canvas.clipRoundRect(rect,height*.09f,height*.09f);cover(canvas,image(c,index),rect);canvas.drawRect(rect,Paint().apply{color=0x180A0413});canvas.restoreToCount(save);return b}
}
