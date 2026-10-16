package vn.edu.phenikaa.better_phenikaa_schedule
import android.graphics.*
import org.json.JSONObject
import kotlin.math.*
/** One frozen world-space RGB field; never a timer or background frame loop. */
internal object WaterWidgetRenderer {
 private fun json(c:WidgetThemeV14)=runCatching{JSONObject(c.waterCooling)}.getOrDefault(JSONObject())
 fun sample(c:WidgetThemeV14,x:Float,y:Float):Int=sample(json(c),x,y)
 private fun sample(c:JSONObject,x:Float,y:Float):Int {
  val colors=c.optJSONArray("colors");val count=(colors?.length()?:0).coerceIn(1,4)
  fun color(i:Int)=colors?.optLong(i.mod(count),0xFFAC70FF)?.toInt()?:0xFFAC70FF.toInt()
  fun fract(v:Double)=v-floor(v)
  fun palette(u:Double):Int{val v=fract(u)*count;return WidgetVisualPalette.mix(color(v.toInt()),color(v.toInt()+1),(v%1).toFloat())}
  val angle=c.optDouble("direction",0.0)*PI/180;val p=(x-.5)*cos(angle)+(y-.5)*sin(angle)+.5
  var rgb=color(0);var light=1.0;val width=c.optDouble("beamWidth",.16).coerceIn(.02,1.0)
  when(c.optString("mode","wave")){
   "rainbow"->rgb=Color.HSVToColor(floatArrayOf((fract(p)*360).toFloat(),.8f,1f))
   "rainbowLine"->rgb=Color.HSVToColor(floatArrayOf((fract(x*(3*cos(angle)+2*sin(angle))+y*(-3*sin(angle)+2*cos(angle)))*360).toFloat(),.8f,1f))
   "wave"->rgb=palette(p/c.optDouble("waveWidth",.65).coerceIn(.08,2.0))
   "beam"->light=.06+.94*exp(-((fract(p)-.5)/width).pow(2))
   "meteor"->light=.06+.94*exp(-fract(p)/width)
   "fire"->{val f=(.5+.25*sin(x*8.0)+.25*sin(y*13.0+x*4.0)).coerceIn(0.0,1.0);rgb=WidgetVisualPalette.mix(0xFFB91E09.toInt(),0xFFFFC85B.toInt(),f.toFloat());light=.35+.65*f}
   "breathing"->light=.59
   "gradient"->rgb=palette(p*.65)
   "custom"->rgb=palette(p)
  }
  val intensity=c.optDouble("intensity",.65).coerceIn(0.0,1.0);val gain=c.optDouble("brightness",.7).coerceIn(0.0,1.0)*(1-intensity+intensity*light)
  return Color.rgb((Color.red(rgb)*gain).roundToInt().coerceIn(0,255),(Color.green(rgb)*gain).roundToInt().coerceIn(0,255),(Color.blue(rgb)*gain).roundToInt().coerceIn(0,255))
 }
 fun background(canvas:Canvas,width:Int,height:Int,config:WidgetThemeV14){val c=json(config);val colors=c.optJSONArray("colors");val purple=colors?.optLong(0,0xFFAC70FF)?.toInt()?:0xFFAC70FF.toInt();val pink=colors?.optLong(1,0xFFFF4DAD)?.toInt()?:0xFFFF4DAD.toInt();val red=colors?.optLong(2,0xFFEE315E)?.toInt()?:0xFFEE315E.toInt();val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply{shader=LinearGradient(0f,0f,width.toFloat(),height.toFloat(),0xFF10091A.toInt(),0xFF201022.toInt(),Shader.TileMode.CLAMP)};canvas.drawRect(0f,0f,width.toFloat(),height.toFloat(),paint)
 fun bloom(x:Float,y:Float,color:Int,radius:Float,alpha:Int){paint.shader=RadialGradient(x,y,radius,intArrayOf(WidgetVisualPalette.withAlpha(color,alpha),WidgetVisualPalette.withAlpha(color,0)),null,Shader.TileMode.CLAMP);canvas.drawRect(0f,0f,width.toFloat(),height.toFloat(),paint)}
 bloom(width*.12f,height*.1f,purple,width*.8f,110);bloom(width*.8f,height*.95f,pink,width*.72f,75);bloom(width*.98f,height*.12f,red,width*.48f,70)
 }
 private fun field(config:WidgetThemeV14,canvas:Canvas,frame:RectF):Pair<Bitmap,Shader>{val settings=json(config);val bitmap=Bitmap.createBitmap(96,48,Bitmap.Config.ARGB_8888);bitmap.setPixels(IntArray(96*48){i->sample(settings,frame.left+(i%96)/95f*frame.width(),frame.top+(i/96)/47f*frame.height())},0,96,0,0,96,48);val shader=BitmapShader(bitmap,Shader.TileMode.CLAMP,Shader.TileMode.CLAMP).apply{setLocalMatrix(Matrix().apply{setScale(canvas.width/96f,canvas.height/48f)})};return Pair(bitmap,shader)}
 fun overlay(canvas:Canvas,surface:WidgetSurface,width:Int,height:Int,density:Float,config:WidgetThemeV14,radius:Float){if(!json(config).optBoolean("border",true))return;val f=field(config,canvas,RectF(0f,0f,1f,1f));chamber(canvas,RectF(0f,0f,width.toFloat(),height.toFloat()),config,radius,density,f.second);if(surface==WidgetSurface.WIDGET2){val inset=max(7f,height*.055f);chamber(canvas,RectF(width*.69f,inset,width-inset,height-inset),config,height*.09f,density*.6f,f.second)};f.first.recycle()}
 fun card(canvas:Canvas,rect:RectF,config:WidgetThemeV14,density:Float,normalizedWorldRect:RectF=RectF(0f,0f,.68f,1f)){if(!json(config).optBoolean("border",true))return;val f=field(config,canvas,normalizedWorldRect);chamber(canvas,rect,config,4*density,density*.35f,f.second);f.first.recycle()}
 private fun chamber(canvas:Canvas,bounds:RectF,config:WidgetThemeV14,radius:Float,density:Float,field:Shader){val thickness=(json(config).optDouble("tubeWidth",1.6)*density).toFloat().coerceAtLeast(.7f);val r=RectF(bounds).apply{inset(thickness+1,thickness+1)};if(r.width()<=0||r.height()<=0)return;val p=Paint(Paint.ANTI_ALIAS_FLAG).apply{style=Paint.Style.STROKE;strokeWidth=thickness+2*density;color=0xFF39434C.toInt()};canvas.drawRoundRect(r,radius,radius,p);p.shader=field;p.strokeWidth=thickness;canvas.drawRoundRect(r,radius,radius,p);p.shader=null;p.color=0x5ADEEFF2;p.strokeWidth=.55f*density;canvas.drawRoundRect(RectF(r).apply{offset(0f,-.5f*density)},radius,radius,p);p.style=Paint.Style.FILL;p.color=WidgetVisualPalette.mix(0xFF182027.toInt(),0xFF6A767C.toInt(),json(config).optDouble("metal",.55).toFloat());canvas.drawRoundRect(RectF(r.left+radius,r.top-2*density,r.left+radius+5*density,r.top+2*density),density,density,p)}
}
