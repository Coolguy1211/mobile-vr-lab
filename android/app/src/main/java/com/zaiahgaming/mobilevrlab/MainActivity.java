package com.zaiahgaming.mobilevrlab;

import android.app.Activity;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(Color.rgb(8, 11, 16));
        getWindow().setNavigationBarColor(Color.rgb(8, 11, 16));
        setContentView(new LabView(this));
    }

    static class Line {
        final String stamp, text;
        Line(String s, String t) { stamp = s; text = t; }
    }

    static class LabView extends View {
        final Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        final float d;
        final List<Line> transcript = new ArrayList<>();
        int page = 0; // 0 overview, 1 transcript, 2 guide
        float scroll = 0, downY, lastY;
        boolean moved;
        final int bg = Color.rgb(8, 11, 16), panel = Color.rgb(18, 24, 31), soft = Color.rgb(28, 37, 45);
        final int ink = Color.rgb(239, 244, 238), muted = Color.rgb(157, 170, 174), lime = Color.rgb(184, 244, 106);
        final int orange = Color.rgb(255, 145, 84), cyan = Color.rgb(114, 221, 226);

        LabView(Context c) {
            super(c); d = getResources().getDisplayMetrics().density;
            setFocusable(true);
            try (BufferedReader r = new BufferedReader(new InputStreamReader(c.getAssets().open("transcript.txt")))) {
                String line;
                while ((line = r.readLine()) != null) {
                    int space = line.indexOf(' ');
                    if (space > 0) transcript.add(new Line(line.substring(0, space), line.substring(space + 1)));
                }
            } catch (Exception ignored) {}
        }
        float px(float v) { return v * d; }
        void rect(Canvas c, int color, float l, float t, float r, float b, float rad) { p.setColor(color); p.setStyle(Paint.Style.FILL); c.drawRoundRect(new RectF(px(l), px(t), px(r), px(b)), px(rad), px(rad), p); }
        void text(Canvas c, String s, float x, float y, float size, int color, boolean bold) { p.setColor(color); p.setTextSize(px(size)); p.setTypeface(bold ? Typeface.create("sans", Typeface.BOLD) : Typeface.create("sans", Typeface.NORMAL)); p.setStyle(Paint.Style.FILL); c.drawText(s, px(x), px(y), p); }
        float wrap(Canvas c, String s, float x, float y, float width, float size, int color, boolean bold, float gap) {
            p.setTextSize(px(size)); p.setTypeface(bold ? Typeface.create("sans", Typeface.BOLD) : Typeface.create("sans", Typeface.NORMAL));
            String[] words = s.split(" "); String line = ""; float yy = y;
            for (String w : words) { String candidate = line.isEmpty() ? w : line + " " + w; if (p.measureText(candidate) > px(width) && !line.isEmpty()) { text(c, line, x, yy, size, color, bold); yy += gap; line = w; } else line = candidate; }
            if (!line.isEmpty()) { text(c, line, x, yy, size, color, bold); yy += gap; }
            return yy;
        }
        @Override protected void onDraw(Canvas c) {
            super.onDraw(c); c.drawColor(bg); header(c); if (page == 0) overview(c); else if (page == 1) transcript(c); else guide(c);
        }
        void header(Canvas c) {
            text(c, "MOBILE VR LAB", 22, 30, 12, lime, true);
            text(c, "Phone-powered PC VR", 22, 51, 22, ink, true);
            rect(c, soft, getWidth()/d - 64, 17, getWidth()/d - 22, 58, 20); text(c, "VR", getWidth()/d - 53, 44, 14, ink, true);
            float w = getWidth()/d; float y = 73;
            String[] tabs = {"Overview", "Transcript", "Guide"}; float[] xs = {18, 112, 222};
            for (int i=0;i<3;i++) { if (page == i) rect(c, lime, xs[i]-8, y-17, xs[i]+(i==1?82:65), y+13, 16); text(c, tabs[i], xs[i], y+3, 13, page==i?bg:muted, true); }
        }
        void overview(Canvas c) {
            c.save(); c.translate(0, px(-scroll)); float w=getWidth()/d;
            rect(c, Color.rgb(31, 51, 45), 16, 111, w-16, 270, 26);
            text(c, "FIELD NOTE 01", 31, 139, 11, lime, true);
            float y=166; y=wrap(c, "PC VR, reimagined for a phone.", 31, y, w-62, 27, ink, true, 31);
            y=wrap(c, "A timestamped companion to a mobile tracking experiment using an off-the-shelf VR headset, phone cameras, and a computer-side bridge.", 31, y+4, w-62, 14, Color.rgb(206, 220, 211), false, 20);
            rect(c, Color.rgb(46, 67, 53), 31, 235, 153, 258, 12); text(c, "iPhone 12 Pro", 43, 251, 11, ink, true);
            rect(c, Color.rgb(46, 67, 53), 161, 235, 250, 258, 12); text(c, "Steam VR", 173, 251, 11, ink, true);
            text(c, "14:48  •  3 tracking layers", 31, 294, 12, muted, false);
            text(c, "THE SIGNAL", 22, 326, 11, orange, true);
            text(c, "What the project prioritizes", 22, 351, 20, ink, true);
            float cardY=370; cardY=stat(c, 18, cardY, w/2-25, "60", "Hz head tracking", lime); stat(c, w/2+7, 370, w-18, "45", "Hz hands ceiling", cyan);
            stat(c, 18, 457, w/2-25, "15", "Hz eye tracking", orange); stat(c, w/2+7, 457, w-18, "2:06", "battery test", ink);
            text(c, "THE STORY", 22, 560, 11, cyan, true); text(c, "Follow the build", 22, 585, 20, ink, true);
            float yy=610; yy=chapter(c,yy,"00:01","The premise","A phone handles head, hand, and eye tracking while a PC renders VR."); yy=chapter(c,yy,"03:03","Hand tracking","Smoothing, depth, gestures, and the 1× camera trade-off."); yy=chapter(c,yy,"07:46","Eye tracking","Calibration, pupil position, FOV, and headset fit constraints."); yy=chapter(c,yy,"13:15","Battery + what comes next","Runtime measurements and ideas for extending hand range.");
            text(c, "Read every timestamp", 22, yy+24, 14, lime, true); text(c, "Open the Transcript tab", 22, yy+47, 13, muted, false); setScrollLimit(yy+100);
            c.restore();
        }
        float stat(Canvas c,float l,float t,float r,String big,String label,int color) { rect(c,panel,l,t,r,t+70,19); text(c,big,l+16,t+31,25,color,true); text(c,label,l+16,t+53,11,muted,false); return t+78; }
        float chapter(Canvas c,float y,String time,String title,String desc) { float w=getWidth()/d; rect(c,panel,18,y,w-18,y+82,19); text(c,time,32,y+27,12,lime,true); text(c,title,104,y+27,15,ink,true); wrap(c,desc,104,y+49,w-126,12,muted,false,16); return y+94; }
        void transcript(Canvas c) {
            c.save(); c.translate(0, px(-scroll)); float w=getWidth()/d; text(c,"FULL TRANSCRIPT",22,115,11,lime,true); text(c,"Every timestamp from the source video",22,138,16,ink,true); rect(c,Color.rgb(25,33,40),18,154,w-18,194,16); text(c,"⌕  Scroll to read the complete field note",32,180,13,muted,false); float y=224;
            for (Line line: transcript) { text(c,line.stamp,22,y,11,lime,true); y=wrap(c,line.text,78,y,w-99,13,ink,false,18)+12; if (y-scroll > getHeight()/d+20) break; }
            setScrollLimit(y+40); c.restore();
        }
        void guide(Canvas c) {
            c.save(); c.translate(0, px(-scroll)); float w=getWidth()/d; text(c,"BUILD NOTES",22,116,11,orange,true); text(c,"A practical reading of the experiment",22,141,22,ink,true); float y=176;
            y=guideCard(c,y,"01","Head tracking","Use a stable visual-inertial odometry source first. The project keeps this at 60 Hz and gives it the highest priority so the phone remains responsive.",lime);
            y=guideCard(c,y,"02","Hands + depth","Two-hand tracking is capped around 45 Hz, then smoothed on the computer side. Finger curl works; finger spread and perfect joint accuracy remain harder problems.",cyan);
            y=guideCard(c,y,"03","Eye calibration","A region of interest, red ellipse, green pupil ellipse, and a white eye-center point turn pupil movement into normalized VR input. Screen brightness and headset fit matter.",orange);
            y=guideCard(c,y,"04","Battery reality","Running cameras and tracking together is a thermal and battery trade-off. The experiment measured a little over two hours in one full test, with more data needed.",ink);
            text(c,"Source video",22,y+20,12,muted,true); wrap(c,"This app is a companion and reading tool; it does not claim to reproduce the original computer-side Steam VR bridge.",22,y+47,w-44,13,muted,false,19); setScrollLimit(y+115); c.restore();
        }
        float guideCard(Canvas c,float y,String n,String title,String desc,int color) { float w=getWidth()/d; rect(c,panel,18,y,w-18,y+142,22); text(c,n,34,y+31,12,color,true); text(c,title,78,y+31,17,ink,true); wrap(c,desc,34,y+62,w-68,13,muted,false,19); return y+158; }
        void setScrollLimit(float content) { float viewport=getHeight()/d-96; scroll=Math.max(0,Math.min(scroll,Math.max(0,content-viewport))); }
        @Override public boolean onTouchEvent(MotionEvent e) {
            float x=e.getX()/d,y=e.getY()/d;
            if (e.getAction()==MotionEvent.ACTION_DOWN) { downY=lastY=y; moved=false; return true; }
            if (e.getAction()==MotionEvent.ACTION_MOVE) { float dy=y-lastY; if(Math.abs(y-downY)>5)moved=true; scroll-=dy; lastY=y; invalidate(); return true; }
            if (e.getAction()==MotionEvent.ACTION_UP) {
                if (!moved && y>=48 && y<=105) { if(x<105)page=0; else if(x<210)page=1; else page=2; scroll=0; invalidate(); return true; }
                return true;
            }
            return true;
        }
    }
}
