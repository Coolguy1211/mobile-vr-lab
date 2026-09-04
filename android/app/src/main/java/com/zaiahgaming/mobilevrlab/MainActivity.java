package com.zaiahgaming.mobilevrlab;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.os.Bundle;
import android.view.Gravity;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Collections;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity implements SensorEventListener {
    private TrackerSurface tracker;
    private TextureView cameraPreview;
    private CameraDevice camera;
    private CameraCaptureSession captureSession;
    private SensorManager sensors;
    private EditText hostField;
    private boolean transmitting = false;
    private final ExecutorService network = Executors.newSingleThreadExecutor();
    private float yaw, pitch, roll;
    private long sequence;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(Color.rgb(8,11,16)); getWindow().setNavigationBarColor(Color.rgb(8,11,16));
        FrameLayout root = new FrameLayout(this);
        cameraPreview = new TextureView(this); cameraPreview.setAlpha(0.42f); cameraPreview.setSurfaceTextureListener(new CameraPreviewListener()); root.addView(cameraPreview, new FrameLayout.LayoutParams(-1,-1));
        tracker = new TrackerSurface(this); root.addView(tracker, new FrameLayout.LayoutParams(-1,-1));
        LinearLayout controls = new LinearLayout(this); controls.setOrientation(LinearLayout.HORIZONTAL); controls.setGravity(Gravity.CENTER_VERTICAL); controls.setPadding(16,10,16,10); controls.setBackgroundColor(Color.argb(225,8,11,16));
        hostField = new EditText(this); hostField.setText("192.168.0.172"); hostField.setTextColor(Color.WHITE); hostField.setHintTextColor(Color.GRAY); hostField.setHint("PC IP"); hostField.setSingleLine(true); hostField.setTextSize(13); hostField.setInputType(1); controls.addView(hostField, new LinearLayout.LayoutParams(170, ViewGroup.LayoutParams.WRAP_CONTENT));
        TextView port = new TextView(this); port.setText("  UDP 9000  "); port.setTextColor(Color.LTGRAY); controls.addView(port, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        Button button = new Button(this); button.setText("Start pose stream"); button.setOnClickListener(v -> { transmitting = !transmitting; button.setText(transmitting ? "Stop pose stream" : "Start pose stream"); tracker.invalidate(); }); controls.addView(button, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        FrameLayout.LayoutParams cp = new FrameLayout.LayoutParams(-1, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM); root.addView(controls, cp);
        setContentView(root);
        sensors = (SensorManager)getSystemService(SENSOR_SERVICE); Sensor rotation = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR); if (rotation != null) sensors.registerListener(this, rotation, SensorManager.SENSOR_DELAY_GAME);
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) requestPermissions(new String[]{Manifest.permission.CAMERA}, 7);
    }
    @Override public void onResume() { super.onResume(); if (sensors != null) { Sensor s=sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR); if(s!=null)sensors.registerListener(this,s,SensorManager.SENSOR_DELAY_GAME); } }
    @Override public void onPause() { super.onPause(); if(sensors!=null)sensors.unregisterListener(this); closeCamera(); }
    @Override public void onDestroy() { super.onDestroy(); closeCamera(); network.shutdownNow(); }
    @Override public void onSensorChanged(SensorEvent e) {
        if(e.sensor.getType()!=Sensor.TYPE_ROTATION_VECTOR)return; float[] m=new float[9]; SensorManager.getRotationMatrixFromVector(m,e.values); float[] o=new float[3]; SensorManager.getOrientation(m,o); yaw=(float)Math.toDegrees(o[0]); pitch=(float)Math.toDegrees(o[1]); roll=(float)Math.toDegrees(o[2]); tracker.setPose(yaw,pitch,roll,transmitting); if(transmitting) sendPose();
    }
    @Override public void onAccuracyChanged(Sensor s,int a) {}
    private void sendPose() { final String host=hostField.getText().toString().trim(); final String json="{\"type\":\"pose\",\"source\":\"android-sensors\",\"seq\":"+(sequence++)+",\"timestamp\":"+(System.currentTimeMillis()/1000.0)+",\"yaw\":"+yaw+",\"pitch\":"+pitch+",\"roll\":"+roll+",\"x\":0,\"y\":0,\"z\":0}"; network.submit(() -> { try(DatagramSocket socket=new DatagramSocket()) { byte[] bytes=json.getBytes(StandardCharsets.UTF_8); socket.send(new DatagramPacket(bytes,bytes.length,java.net.InetAddress.getByName(host),9000)); } catch(Exception ignored) {} }); }
    private void openCamera() { if(checkSelfPermission(Manifest.permission.CAMERA)!=PackageManager.PERMISSION_GRANTED || !cameraPreview.isAvailable()) return; try { CameraManager manager=(CameraManager)getSystemService(CAMERA_SERVICE); String id=manager.getCameraIdList()[0]; manager.openCamera(id,new CameraDevice.StateCallback(){ public void onOpened(CameraDevice c){camera=c; startPreview();} public void onDisconnected(CameraDevice c){c.close();camera=null;} public void onError(CameraDevice c,int e){c.close();camera=null;} },null); } catch(Exception ignored) {} }
    private void startPreview() { try { Surface s=new Surface(cameraPreview.getSurfaceTexture()); android.hardware.camera2.CaptureRequest.Builder b=camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW); b.addTarget(s); camera.createCaptureSession(Collections.singletonList(s),new CameraCaptureSession.StateCallback(){ public void onConfigured(CameraCaptureSession cs){captureSession=cs; try{cs.setRepeatingRequest(b.build(),null,null);}catch(Exception ignored){}} public void onConfigureFailed(CameraCaptureSession cs){} },null); } catch(Exception ignored) {} }
    private void closeCamera(){ if(captureSession!=null){captureSession.close();captureSession=null;} if(camera!=null){camera.close();camera=null;} }
    @Override public void onRequestPermissionsResult(int r,String[] p,int[] g){super.onRequestPermissionsResult(r,p,g); if(r==7 && g.length>0 && g[0]==PackageManager.PERMISSION_GRANTED)openCamera();}
    private class CameraPreviewListener implements TextureView.SurfaceTextureListener { public void onSurfaceTextureAvailable(android.graphics.SurfaceTexture s,int w,int h){openCamera();} public void onSurfaceTextureSizeChanged(android.graphics.SurfaceTexture s,int w,int h){} public boolean onSurfaceTextureDestroyed(android.graphics.SurfaceTexture s){closeCamera();return true;} public void onSurfaceTextureUpdated(android.graphics.SurfaceTexture s){} }

    static class TrackerSurface extends View {
        private final Paint p=new Paint(Paint.ANTI_ALIAS_FLAG); private final float d; private float yaw,pitch,roll; private boolean live;
        TrackerSurface(Context c){super(c);d=getResources().getDisplayMetrics().density;setLayerType(View.LAYER_TYPE_SOFTWARE,null);}
        void setPose(float y,float pi,float r,boolean l){yaw=y;pitch=pi;roll=r;live=l;postInvalidate();}
        void rounded(Canvas c,int color,float l,float t,float r,float b,float rad){p.setColor(color);p.setStyle(Paint.Style.FILL);c.drawRoundRect(new RectF(l*d,t*d,r*d,b*d),rad*d,rad*d,p);}
        void txt(Canvas c,String s,float x,float y,float size,int color,boolean bold){p.setColor(color);p.setTextSize(size*d);p.setTypeface(Typeface.create("sans",bold?Typeface.BOLD:Typeface.NORMAL));c.drawText(s,x*d,y*d,p);}
        @Override protected void onDraw(Canvas c){super.onDraw(c);float w=getWidth()/d,h=getHeight()/d;int ink=Color.rgb(239,244,238),muted=Color.rgb(161,174,177),green=Color.rgb(184,244,106); txt(c,"POCKETVR BRIDGE",22,31,12,green,true); txt(c,"ANDROID SENSOR + CAMERA MODE",22,51,15,ink,true); txt(c,live?"POSE STREAM ON":"POSE STREAM OFF",w-142,31,11,live?green:muted,true); rounded(c,Color.argb(150,8,13,18),12,72,w-12,h-90,22); p.setColor(Color.argb(160,255,255,255));c.drawRect(w/2*d-1,72*d,w/2*d+1,(h-90)*d,p); drawEye(c, w/4, (h-18)/2, -1, green); drawEye(c, w*3/4, (h-18)/2, 1, green); txt(c,String.format("yaw %+.1f°  pitch %+.1f°  roll %+.1f°",yaw,pitch,roll),22,h-108,13,ink,false); txt(c,"Camera preview is active behind the stereo overlay",22,h-88,11,muted,false); }
        void drawEye(Canvas c,float cx,float cy,int side,int col){float shift=(float)(yaw*side*0.8);p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(2*d);p.setColor(col);c.drawCircle((cx+shift)*d,cy*d,24*d,p);p.setStrokeWidth(1*d);p.setColor(Color.WHITE);c.drawLine((cx+shift-35)*d,cy*d,(cx+shift+35)*d,cy*d,p);c.drawLine((cx+shift)*d,(cy-35)*d,(cx+shift)*d,(cy+35)*d,p);p.setStyle(Paint.Style.FILL);}
    }
}
