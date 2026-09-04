#!/usr/bin/env python3
import json, socket, subprocess, sys, tempfile, time, urllib.request
from pathlib import Path
here=Path(__file__).resolve().parent
state=Path(tempfile.gettempdir())/'pocketvr-test-state.json'
try: state.unlink()
except FileNotFoundError: pass
cmd=[sys.executable,str(here/'pocketvr_bridge.py'),'--udp-port','19000','--http-port','19001','--state-file',str(state)]
p=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
try:
    data=None
    deadline=time.time()+5
    while time.time()<deadline:
        try:
            data=json.load(urllib.request.urlopen('http://127.0.0.1:19001/api/openxr',timeout=0.5)); break
        except Exception: time.sleep(.1)
    assert data is not None, 'bridge HTTP endpoint did not start'
    packet={"type":"pose","source":"integration-test","yaw":12.5,"pitch":-3.0,"roll":1.25,"x":.1,"y":.2,"z":-.4}
    s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.sendto(json.dumps(packet).encode(),('127.0.0.1',19000)); s.close()
    deadline=time.time()+5
    while time.time()<deadline:
        data=json.load(urllib.request.urlopen('http://127.0.0.1:19001/api/openxr',timeout=1))
        if data.get('source')=='integration-test': break
        time.sleep(.1)
    assert data['yaw']==12.5 and data['openxr_layer']=='xrLocateViews interceptor' and data['connected']
    print('bridge integration: PASS')
finally:
    p.terminate()
    try: p.wait(timeout=3)
    except subprocess.TimeoutExpired: p.kill(); p.wait(timeout=3)
