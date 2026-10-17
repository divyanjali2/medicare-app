import os
import time
import json
import urllib.request
import base64
import websocket

tabs = json.loads(urllib.request.urlopen('http://localhost:51741/json').read().decode())
page = [t for t in tabs if t.get('type') == 'page' and 'MediCare' in t.get('title', '')][0]
ws_url = page['webSocketDebuggerUrl']

def get_ws():
    return websocket.create_connection(ws_url, suppress_origin=True)

msg_counter = 1
def send_cdp(ws, method, params=None):
    global msg_counter
    msg_counter += 1
    ws.send(json.dumps({'id': msg_counter, 'method': method, 'params': params or {}}))
    while True:
        res = json.loads(ws.recv())
        if res.get('id') == msg_counter:
            return res

def capture_screen(target_filename):
    ws = get_ws()
    send_cdp(ws, 'Page.reload')
    time.sleep(3.0)
    send_cdp(ws, 'Emulation.setDeviceMetricsOverride', {'width': 412, 'height': 850, 'deviceScaleFactor': 2.0, 'mobile': True})
    time.sleep(1.0)
    res = send_cdp(ws, 'Page.captureScreenshot', {'format': 'png'})
    out_path = os.path.join('docs', 'figures', target_filename)
    with open(out_path, 'wb') as f:
        f.write(base64.b64decode(res['result']['data']))
    print(f"Captured {target_filename} ({len(res['result']['data'])} bytes)")
    ws.close()

if __name__ == "__main__":
    capture_screen("test_capture.png")
