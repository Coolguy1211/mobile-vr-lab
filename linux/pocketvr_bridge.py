#!/usr/bin/env python3
"""PocketVR Linux bridge: UDP phone pose -> OpenXR layer state + web dashboard."""
from __future__ import annotations
import argparse, json, os, signal, socket, tempfile, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

INDEX = """<!doctype html><meta name=viewport content='width=device-width,initial-scale=1'><title>PocketVR OpenXR Bridge</title>
<style>body{margin:0;background:#080b10;color:#eff4ee;font:16px system-ui;max-width:900px;margin:auto;padding:32px}h1{font-size:38px;margin:8px 0}.muted{color:#9daaae}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}.card{background:#12181f;border:1px solid #26343a;border-radius:18px;padding:18px}.v{font-size:26px;color:#b8f46a;font-weight:700}code{color:#b8f46a}a{color:#72dde2}.ok{color:#b8f46a}.warn{color:#ff9154}</style>
<p class=muted>POCKETVR • LINUX OPENXR BRIDGE</p><h1>Phone pose → OpenXR</h1><p class=muted>The daemon receives opt-in pose packets from the PocketVR mobile app and publishes the latest pose for the OpenXR API layer.</p>
<div class=grid><div class=card><div class=v id=state>Waiting</div><div class=muted>bridge state</div></div><div class=card><div class=v id=fps>0</div><div class=muted>packets / sec</div></div><div class=card><div class=v id=yaw>0°</div><div class=muted>yaw</div></div><div class=card><div class=v id=source>—</div><div class=muted>source</div></div></div>
<div class=card style='margin-top:18px'><b>OpenXR layer</b><p class=muted>Run an existing OpenXR runtime, then load <code>libpocketvr_openxr_layer.so</code>. The layer intercepts <code>xrLocateViews</code> and applies this phone pose.</p><p><code>python3 pocketvr_bridge.py --udp-port 9000</code></p></div>
<script>async function tick(){try{let s=await fetch('/api/state').then(r=>r.json());state.textContent=s.status;state.className=s.connected?'v ok':'v warn';fps.textContent=s.rate.toFixed(1);yaw.textContent=(s.yaw||0).toFixed(1)+'°';source.textContent=s.source||'—'}catch(e){state.textContent='Offline'}}setInterval(tick,500);tick()</script>"""

class BridgeState:
    def __init__(self, path: Path):
        self.path=path; self.lock=threading.Lock(); self.pose={}; self.received=0; self.window_start=time.monotonic(); self.rate=0.0; self.last_received=0.0
        self.persist({"type":"state","status":"waiting","connected":False,"rate":0.0})
    def persist(self, value):
        self.path.parent.mkdir(parents=True,exist_ok=True)
        fd,tmp=tempfile.mkstemp(prefix='.pocketvr-',dir=self.path.parent)
        try:
            with os.fdopen(fd,'w') as f: json.dump(value,f,separators=(',',':'))
            os.replace(tmp,self.path)
        finally:
            if os.path.exists(tmp): os.unlink(tmp)
    def ingest(self, packet):
        numeric=('yaw','pitch','roll','x','y','z')
        if packet.get('type') not in ('pose','state'): return False
        for key in numeric:
            if key in packet:
                try: packet[key]=float(packet[key])
                except (TypeError,ValueError): packet[key]=0.0
        now=time.time()
        with self.lock:
            self.pose=dict(packet); self.last_received=now; self.received+=1
            elapsed=time.monotonic()-self.window_start
            if elapsed>=0.5: self.rate=self.received/elapsed; self.received=0; self.window_start=time.monotonic()
            snap=self.snapshot_locked(); self.persist(snap)
        return True
    def snapshot_locked(self):
        age=time.time()-self.last_received if self.last_received else 1e9
        s=dict(self.pose); s.update({"status":"connected" if age<3 else "waiting","connected":age<3,"age_seconds":age,"rate":self.rate,"state_file":str(self.path),"openxr_layer":"xrLocateViews interceptor"})
        return s
    def snapshot(self):
        with self.lock: return self.snapshot_locked()

class UDPReceiver(threading.Thread):
    daemon=True
    def __init__(self, state, host, port): super().__init__(); self.state=state; self.host=host; self.port=port; self.stop_event=threading.Event(); self.sock=None
    def run(self):
        self.sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); self.sock.settimeout(0.5); self.sock.bind((self.host,self.port))
        while not self.stop_event.is_set():
            try: data,_=self.sock.recvfrom(8192); packet=json.loads(data.decode('utf-8')); self.state.ingest(packet)
            except (socket.timeout,UnicodeDecodeError,json.JSONDecodeError): continue
            except OSError: break
    def close(self): self.stop_event.set();
    
class Handler(BaseHTTPRequestHandler):
    state=None
    def do_GET(self):
        if self.path in ('/','/index.html'):
            body=INDEX.encode(); self.send_response(200); self.send_header('Content-Type','text/html; charset=utf-8')
        elif self.path in ('/api/state','/api/openxr','/healthz'):
            body=json.dumps(self.state.snapshot()).encode(); self.send_response(200); self.send_header('Content-Type','application/json')
        else: self.send_error(404); return
        self.send_header('Content-Length',str(len(body))); self.send_header('Cache-Control','no-store'); self.end_headers(); self.wfile.write(body)
    def log_message(self,*args): return

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--udp-host',default='0.0.0.0'); ap.add_argument('--udp-port',type=int,default=9000); ap.add_argument('--http-host',default='0.0.0.0'); ap.add_argument('--http-port',type=int,default=8790); ap.add_argument('--state-file',default='/tmp/pocketvr_pose.json'); args=ap.parse_args()
    state=BridgeState(Path(args.state_file)); receiver=UDPReceiver(state,args.udp_host,args.udp_port); receiver.start()
    Handler.state=state; http=ThreadingHTTPServer((args.http_host,args.http_port),Handler)
    print(f'PocketVR bridge listening: UDP {args.udp_host}:{args.udp_port}, HTTP http://{args.http_host}:{args.http_port}',flush=True)
    stop_event=threading.Event()
    def stop(*_): receiver.close(); stop_event.set()
    signal.signal(signal.SIGINT,stop); signal.signal(signal.SIGTERM,stop)
    http.timeout=0.5
    try:
        while not stop_event.is_set(): http.handle_request()
    finally: http.server_close(); receiver.close()
if __name__=='__main__': main()
