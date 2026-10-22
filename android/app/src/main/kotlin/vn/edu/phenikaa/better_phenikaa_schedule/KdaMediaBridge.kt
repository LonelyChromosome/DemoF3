package vn.edu.phenikaa.better_phenikaa_schedule

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.*
import android.media.audiofx.Visualizer
import android.os.*
import android.view.Surface
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.*
import io.flutter.view.TextureRegistry
import kotlin.math.*

/** Exactly one lifecycle-owned decoder; never sends audio events to widgets. */
internal class KdaMediaBridge(private val activity: Activity, private val engine: FlutterEngine): EventChannel.StreamHandler {
 private val handler=Handler(Looper.getMainLooper())
 private val methods=MethodChannel(engine.dartExecutor.binaryMessenger,"better_phenikaa/kda_media")
 private val events=EventChannel(engine.dartExecutor.binaryMessenger,"better_phenikaa/kda_events")
 private val audio=activity.getSystemService(Context.AUDIO_SERVICE) as AudioManager
 private val attributes=AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
 private var sink: EventChannel.EventSink?=null
 private var player: MediaPlayer?=null
 private var texture: TextureRegistry.SurfaceTextureEntry?=null
 private var surface: Surface?=null
 private var capture: Visualizer?=null
 private var captureSession: Int?=null
 private var permissionResult: MethodChannel.Result?=null
 private var focusRequest: AudioFocusRequest?=null
 private var focusOwned=false
 private var enabled=false
 private var video=true
 private var music=false
 private var spectrum=true
 private var foreground=true
 private var prepared=false
 private var ready=false
 private var source: String?=null
 private var savedPosition=0
 private var serial=0
 private var width=1440
 private var height=2560
 private var holding=false
 private var remaining=KdaPlaybackPolicy.HOLD_MS
 private var deadline=0L
 private var seeking=false
 private var loops=0
 private var error: String?=null
 private var captureStatus="Chưa có tín hiệu âm thanh"
 private val focusListener=AudioManager.OnAudioFocusChangeListener { change -> handler.post {
  when(change){AudioManager.AUDIOFOCUS_GAIN->{focusOwned=true;volume();start()}
   AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK->runCatching {player?.setVolume(.18f,.18f)}
   else->{focusOwned=false;if(music)runCatching{player?.pause()};releaseCapture()}}
 } }
 private val loop=Runnable {if(enabled&&foreground&&prepared){holding=false;remaining=KdaPlaybackPolicy.HOLD_MS;seeking=true;loops++;player?.seekTo(0)}}
 init {methods.setMethodCallHandler(::method);events.setStreamHandler(this)}
 override fun onListen(arguments: Any?,eventSink: EventChannel.EventSink){sink=eventSink;state()}
 override fun onCancel(arguments: Any?){sink=null}
 private fun permitted()=Build.VERSION.SDK_INT<23||activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED
 private fun method(call: MethodCall,result: MethodChannel.Result){when(call.method){
  "configure"->runCatching {configure(call.argument<Boolean>("enabled")==true,call.argument<Boolean>("video")!=false,call.argument<Boolean>("music")==true,call.argument<Boolean>("visualizer")!=false);result.success(snapshot())}.onFailure{error=it.message;state();result.error("kda_media",it.message,null)}
  "permission"->{if(permitted())result.success(true)else if(permissionResult!=null)result.success(false)else{permissionResult=result;activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO),PERMISSION)}}
  "state"->result.success(snapshot())
  else->result.notImplemented()
 }}
 fun permissionResult(code: Int){if(code!=PERMISSION)return;permissionResult?.success(permitted());permissionResult=null;refreshCapture();state()}
 private fun configure(active: Boolean,showVideo: Boolean,playMusic: Boolean,showSpectrum: Boolean){
  val entering=active&&!enabled;enabled=active;video=showVideo;music=playMusic;spectrum=showSpectrum
  if(!enabled){serial++;reset();player?.release();player=null;surface?.release();surface=null;texture?.release();texture=null;savedPosition=0;abandonFocus();state();return}
  if(entering){savedPosition=0;loops=0;error=null}
  val target=if(video)VIDEO else if(music)AUDIO else null
  if(source!=target||(target!=null&&player==null)){
   if(prepared)savedPosition=runCatching{player?.currentPosition?:savedPosition}.getOrDefault(savedPosition)
   reset();source=target;if(target!=null)open(target)
  }
  volume();if(target==null){ready=true;abandonFocus()};start();refreshCapture();state()
 }
 private fun reset(){handler.removeCallbacks(loop);releaseCapture();runCatching{player?.reset()};prepared=false;ready=false;source=null;holding=false;seeking=false}
 private fun open(asset: String){
  val generation=++serial;val p=player?:MediaPlayer().also{player=it};p.setAudioAttributes(attributes)
  if(asset==VIDEO){if(texture==null){texture=engine.renderer.createSurfaceTexture();surface=Surface(texture!!.surfaceTexture())};p.setSurface(surface)}else p.setSurface(null)
  activity.assets.openFd(asset).use{p.setDataSource(it.fileDescriptor,it.startOffset,it.length)}
  p.setOnPreparedListener{
   if(generation!=serial||!enabled)return@setOnPreparedListener
   prepared=true;error=null;width=if(video)p.videoWidth.coerceAtLeast(1)else 1440;height=if(video)p.videoHeight.coerceAtLeast(1)else 2560
   if(video)texture?.surfaceTexture()?.setDefaultBufferSize(width,height);ready=!video;volume()
   if(savedPosition>0&&savedPosition<p.duration){seeking=true;p.seekTo(savedPosition)}else start()
   refreshCapture();state()
  }
  p.setOnSeekCompleteListener{if(generation==serial){seeking=false;start();state()}}
  p.setOnInfoListener{_,what,_->if(generation==serial&&what==MediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START){ready=true;state()};false}
  p.setOnCompletionListener{if(generation==serial){holding=true;remaining=KdaPlaybackPolicy.HOLD_MS;releaseCapture();hold();state()}}
  p.setOnErrorListener{_,what,extra->if(generation==serial){prepared=false;ready=false;error="Không giải mã được MV ($what/$extra). Đang dùng ảnh nền đã cung cấp.";releaseCapture();state()};true}
  p.prepareAsync()
 }
 private fun start(){if(!KdaPlaybackPolicy.shouldPlay(enabled,foreground,video,music)||!prepared||seeking)return;if(holding){hold();return};if(music&&!focusOwned)requestFocus();if(music&&!video&&!focusOwned)return;volume();runCatching{if(player?.isPlaying==false)player?.start()};refreshCapture()}
 private fun hold(){handler.removeCallbacks(loop);if(enabled&&foreground){deadline=SystemClock.elapsedRealtime()+remaining;handler.postDelayed(loop,remaining)}}
 fun pause(){foreground=false;if(holding)remaining=(deadline-SystemClock.elapsedRealtime()).coerceAtLeast(0);handler.removeCallbacks(loop);runCatching{if(prepared)player?.pause()};releaseCapture();abandonFocus();state();lifecycleLog("pause")}
 fun resume(){foreground=true;if(enabled){start();refreshCapture();state()};lifecycleLog("resume")}
 private fun lifecycleLog(kind:String){if(activity.packageName.endsWith(".kdatest"))android.util.Log.i("KdaLifecycle",kind+" "+org.json.JSONObject(snapshot()).toString())}
 private fun volume(){if(!enabled){abandonFocus();return};if(music&&foreground&&!focusOwned)requestFocus();if(!music)abandonFocus();val v=if(music&&foreground&&focusOwned)1f else 0f;runCatching{player?.setVolume(v,v)}}
 private fun requestFocus(){if(!enabled||!foreground||!music||focusOwned)return
  val response=if(Build.VERSION.SDK_INT>=26){val req=focusRequest?:AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener).build().also{focusRequest=it};audio.requestAudioFocus(req)}else{
   @Suppress("DEPRECATION")
   audio.requestAudioFocus(focusListener,AudioManager.STREAM_MUSIC,AudioManager.AUDIOFOCUS_GAIN)
  };focusOwned=response==AudioManager.AUDIOFOCUS_REQUEST_GRANTED
 }
 private fun abandonFocus(){if(!focusOwned)return;if(Build.VERSION.SDK_INT>=26)focusRequest?.let{audio.abandonAudioFocusRequest(it)}else{
  @Suppress("DEPRECATION")
  audio.abandonAudioFocus(focusListener)
 };focusOwned=false}
 private fun refreshCapture(){
  if(!enabled||!foreground||!spectrum||holding){releaseCapture();return}
  if(!permitted()){releaseCapture();captureStatus="Cấp quyền âm thanh trong cài đặt theme";return}
  val session=if(music&&prepared)player?.audioSessionId?:0 else 0
  if(capture!=null&&captureSession==session)return
  releaseCapture()
  try{val v=Visualizer(session);capture=v;v.captureSize=Visualizer.getCaptureSizeRange()[1].coerceAtMost(1024);v.scalingMode=Visualizer.SCALING_MODE_AS_PLAYED
   v.setDataCaptureListener(object: Visualizer.OnDataCaptureListener{
    override fun onWaveFormDataCapture(v: Visualizer?,bytes: ByteArray?,rate: Int)=Unit
    override fun onFftDataCapture(v: Visualizer?,fft: ByteArray?,rate: Int){if(fft==null)return;val bands=KdaPlaybackPolicy.fftBands(fft,rate/1000.0);handler.post{if(enabled&&foreground&&capture===v)sink?.success(mapOf("type" to "fft","bands" to bands))}}
   },minOf(16000,Visualizer.getMaxCaptureRate()),false,true);v.enabled=true;captureSession=session
   captureStatus=if(session==0)"Nguồn ngoài phụ thuộc quyền và hỗ trợ của Android"else"Phổ âm thanh từ nhạc FIRESTARTER"
  }catch(_:Exception){releaseCapture();captureStatus="Android chưa cấp tín hiệu nguồn này; có thể bật nhạc FIRESTARTER để dùng nguồn trong app."}
 }
 private fun releaseCapture(){runCatching{capture?.enabled=false};runCatching{capture?.release()};capture=null;captureSession=null;sink?.success(mapOf("type" to "fft","bands" to List(48){0.0}))}
 private fun snapshot(): Map<String,Any?> = mapOf("type" to "state","textureId" to texture?.id(),"width" to width,"height" to height,"ready" to ready,"error" to error,"permission" to permitted(),"captureStatus" to captureStatus,"positionMs" to runCatching{if(prepared)player?.currentPosition?:savedPosition else savedPosition}.getOrDefault(savedPosition),"holding" to holding,"foreground" to foreground,"loops" to loops,"playing" to runCatching{prepared&&player?.isPlaying==true}.getOrDefault(false),"music" to music,"enabled" to enabled)
 private fun state(){sink?.success(snapshot())}
 fun close(){enabled=false;serial++;handler.removeCallbacksAndMessages(null);releaseCapture();abandonFocus();player?.release();surface?.release();texture?.release();player=null;surface=null;texture=null;permissionResult?.success(false);permissionResult=null;methods.setMethodCallHandler(null);events.setStreamHandler(null);sink=null}
 companion object{const val PERMISSION=8463;private const val VIDEO="flutter_assets/assets/kda/firestarter.mp4";private const val AUDIO="flutter_assets/assets/kda/music.m4a"}
}
internal object KdaPlaybackPolicy {
 const val HOLD_MS=3000L
 fun shouldPlay(enabled:Boolean,foreground:Boolean,video:Boolean,music:Boolean)=enabled&&foreground&&(video||music)
 fun fftBands(fft:ByteArray,sampleRate:Double):List<Double>{if(fft.size<4||sampleRate<=0)return List(48){0.0};val nyquist=fft.size/2-1
 return List(48){band->val lo=(35.0*(16000.0/35).pow(band/48.0)*fft.size/sampleRate).toInt().coerceIn(1,nyquist);val hi=(35.0*(16000.0/35).pow((band+1)/48.0)*fft.size/sampleRate).toInt().coerceIn(lo,nyquist);var energy=0.0;for(i in lo..hi)energy=max(energy,hypot(fft[i*2].toDouble(),fft[i*2+1].toDouble()));(ln(1+energy/5.0)/ln(1+128.0/5.0)).coerceIn(0.0,1.0)}
 }
}
