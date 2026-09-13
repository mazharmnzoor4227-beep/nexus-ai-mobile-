package app.nexus.nexus_ai

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfRenderer
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaCodec
import android.os.ParcelFileDescriptor
import android.util.Base64
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class MainActivity: FlutterFragmentActivity() {
 private val worker=Executors.newSingleThreadExecutor()
 private var exportResult: MethodChannel.Result?=null
 private var exportFile: File?=null
 override fun configureFlutterEngine(engine:FlutterEngine){
  super.configureFlutterEngine(engine)
  window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
  MethodChannel(engine.dartExecutor.binaryMessenger,"nexus/native").setMethodCallHandler { call,result ->
   try {
    when(call.method){
     "speaker" -> {val a=getSystemService(AUDIO_SERVICE) as AudioManager;if(call.argument<Boolean>("end")==true){a.clearCommunicationDevice();a.mode=AudioManager.MODE_NORMAL}else{a.mode=AudioManager.MODE_IN_COMMUNICATION;val type=if(call.argument<Boolean>("enabled")==true)AudioDeviceInfo.TYPE_BUILTIN_SPEAKER else AudioDeviceInfo.TYPE_BUILTIN_EARPIECE;val device=a.availableCommunicationDevices.firstOrNull{it.type==type};if(device!=null)a.setCommunicationDevice(device)};result.success(null)}
     "share" -> {val f=checked(call.argument<String>("path")!!);val uri=FileProvider.getUriForFile(this,"$packageName.files",f);startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType(call.argument<String>("mime")?:"application/octet-stream").putExtra(Intent.EXTRA_STREAM,uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),"Share file"));result.success(null)}
     "export" -> {check(exportResult==null){"An export is already open"};exportFile=checked(call.argument<String>("path")!!);exportResult=result;startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType(call.argument<String>("mime")?:"application/octet-stream").putExtra(Intent.EXTRA_TITLE,call.argument<String>("name")?:exportFile!!.name),901)}
     "vision","audio" -> {val file=checked(call.argument<String>("path")!!);worker.execute {try{val value=if(call.method=="audio")audio(file) else vision(file,call.argument<String>("mime")?:"");runOnUiThread{result.success(value)}}catch(e:Exception){runOnUiThread{result.error("MEDIA","Cannot read this media. Try a smaller supported file.",null)}}}}
     else -> result.notImplemented()
    }
   }catch(e:Exception){result.error("FILE","File or device operation failed",null)}
  }
 }
 private fun checked(path:String):File {val f=File(path).canonicalFile;check(f.isFile&&f.length()<=100L*1024*1024);check(f.path.startsWith(filesDir.canonicalPath+"/")||f.path.startsWith(cacheDir.canonicalPath+"/"));return f}
 @Deprecated("Android export callback")
 override fun onActivityResult(requestCode:Int,resultCode:Int,data:Intent?){super.onActivityResult(requestCode,resultCode,data);if(requestCode!=901)return;val result=exportResult;val file=exportFile;exportResult=null;exportFile=null;if(resultCode!=Activity.RESULT_OK||data?.data==null||file==null){result?.success(false);return};val uri=data.data!!;worker.execute {try {contentResolver.openOutputStream(uri,"w")!!.use{out->file.inputStream().use{it.copyTo(out)}};runOnUiThread{result?.success(true)}}catch(e:Exception){runOnUiThread{result?.error("EXPORT","Could not save the file",null)}}}}
 private fun image(bitmap:Bitmap):Map<String,Any>{val ratio=1024.0/maxOf(bitmap.width,bitmap.height);val scaled=if(ratio<1)Bitmap.createScaledBitmap(bitmap,maxOf(1,(bitmap.width*ratio).toInt()),maxOf(1,(bitmap.height*ratio).toInt()),true)else bitmap;val out=ByteArrayOutputStream();scaled.compress(Bitmap.CompressFormat.JPEG,80,out);if(scaled!==bitmap)scaled.recycle();return mapOf("type" to "image_url","image_url" to mapOf("url" to "data:image/jpeg;base64,"+Base64.encodeToString(out.toByteArray(),Base64.NO_WRAP)))}
 private fun text(value:String):Map<String,Any> = mapOf("type" to "text","text" to value)
 private fun vision(file:File,mime:String):List<Map<String,Any>> {
  if(mime=="application/pdf") {val result=mutableListOf<Map<String,Any>>();ParcelFileDescriptor.open(file,ParcelFileDescriptor.MODE_READ_ONLY).use{fd->PdfRenderer(fd).use{pdf->check(pdf.pageCount>0);result.add(text("PDF ${pdf.pageCount} pages; up to 8 representative pages shown."));for(i in 0 until minOf(8,pdf.pageCount)){val n=if(pdf.pageCount<=8)i else i*(pdf.pageCount-1)/7;pdf.openPage(n).use{page->val scale=1200.0/maxOf(page.width,page.height);val b=Bitmap.createBitmap(maxOf(1,(page.width*scale).toInt()),maxOf(1,(page.height*scale).toInt()),Bitmap.Config.ARGB_8888);b.eraseColor(android.graphics.Color.WHITE);page.render(b,null,null,PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);result.add(text("Page ${n+1}"));result.add(image(b));b.recycle()}}}};return result}
  if(mime.startsWith("video/")){val r=MediaMetadataRetriever();try{r.setDataSource(file.path);val duration=r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong()?:0;check(duration in 1..3600000);val result=mutableListOf<Map<String,Any>>(text("Video duration ${duration/1000.0}s. Sampled key frames; unsampled events may be omitted."));var previous:IntArray?=null;for(window in 0..7){var best:Bitmap?=null;var bestTime=0L;var score=-1L;for(candidate in 0..2){val time=((window+candidate/3.0)/8*duration).toLong();val b=r.getScaledFrameAtTime(time*1000,MediaMetadataRetriever.OPTION_CLOSEST_SYNC,640,480)?:continue;val tiny=Bitmap.createScaledBitmap(b,16,16,false);val pixels=IntArray(256);tiny.getPixels(pixels,0,16,0,0,16,16);tiny.recycle();val delta=if(previous==null)1L else pixels.indices.sumOf{kotlin.math.abs((pixels[it]and 255)-(previous!![it]and 255)).toLong()};if(delta>score){best?.recycle();best=b;bestTime=time;score=delta}else b.recycle()};if(best!=null){result.add(text("Frame at ${bestTime/1000.0}s"));result.add(image(best));val tiny=Bitmap.createScaledBitmap(best,16,16,false);previous=IntArray(256);tiny.getPixels(previous!!,0,16,0,0,16,16);tiny.recycle();best.recycle()}};return result}finally{r.release()}}
  check(mime.startsWith("image/"));val o=BitmapFactory.Options().apply{inJustDecodeBounds=true};BitmapFactory.decodeFile(file.path,o);check(o.outWidth>0&&o.outHeight>0);o.inSampleSize=1;while(maxOf(o.outWidth,o.outHeight)/o.inSampleSize>1600)o.inSampleSize*=2;o.inJustDecodeBounds=false;val b=BitmapFactory.decodeFile(file.path,o)?:error("Invalid image");try{return listOf(image(b))}finally{b.recycle()}
 }
 private fun audio(file:File):String? {val extractor=MediaExtractor();var muxer:MediaMuxer?=null;val out=File(cacheDir,"audio-${java.util.UUID.randomUUID()}.m4a");try{extractor.setDataSource(file.path);val track=(0 until extractor.trackCount).firstOrNull{extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/")==true}?:return null;extractor.selectTrack(track);val format=extractor.getTrackFormat(track);val writer=MediaMuxer(out.path,MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);muxer=writer;val target=writer.addTrack(format);writer.start();val buffer=ByteBuffer.allocate(2*1024*1024);val info=MediaCodec.BufferInfo();var total=0L;while(true){val size=extractor.readSampleData(buffer,0);if(size<0)break;total+=size;check(total<=25L*1024*1024);info.set(0,size,extractor.sampleTime,extractor.sampleFlags);writer.writeSampleData(target,buffer,info);extractor.advance()};writer.stop();return out.path}catch(e:Exception){out.delete();throw e}finally{muxer?.release();extractor.release()}}
 override fun onDestroy(){exportResult?.error("CLOSED","Activity closed",null);exportResult=null;worker.shutdown();super.onDestroy()}
}
