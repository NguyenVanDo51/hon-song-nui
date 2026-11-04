"""Smoke-test the exported web build in a real (headless) browser via the DevTools protocol.
Serves build/web, opens it in headless Edge/Chrome with software WebGL, waits real time, prints the page console,
saves screenshots. Optional clicks (viewport px) let it walk through menus.
usage: python tools/web_smoke.py [--query "?screen=campaign"] [--wait 40] [--out shots/web.png] [--click 690,457 --wait2 5 --out2 shots/web2.png]
needs: pip install websocket-client
"""
import argparse, base64, http.server, json, os, socketserver, subprocess, sys, threading, time, urllib.request
import websocket

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(ROOT, "build", "web")
ap = argparse.ArgumentParser()
ap.add_argument("--query", default="")
ap.add_argument("--url", default="", help="test a deployed site instead of build/web, e.g. https://hon-song-nui.vercel.app/")
ap.add_argument("--wait", type=float, default=40)
ap.add_argument("--idb", action="store_true", help="print the IndexedDB keys (saved files) after --wait")
ap.add_argument("--out", default="shots/web.png")
ap.add_argument("--click", action="append", default=[])
ap.add_argument("--wait2", type=float, default=4)
ap.add_argument("--out2", default="shots/web2.png")
a = ap.parse_args()
sys.stdout.reconfigure(encoding="utf-8")

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *k, **kw): super().__init__(*k, directory=WEB, **kw)
    def log_message(self, *k): pass
H.extensions_map[".wasm"] = "application/wasm"
srv = socketserver.ThreadingTCPServer(("127.0.0.1", 0), H)
port = srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()

browsers = [os.path.expandvars(p) for p in [r"%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe", r"%ProgramFiles%\Microsoft\Edge\Application\msedge.exe",
    r"%ProgramFiles%\Google\Chrome\Application\chrome.exe"]]
exe = next(p for p in browsers if os.path.exists(p))
prof = os.path.join(os.environ["TEMP"], "hsn_cdp_profile")
proc = subprocess.Popen([exe, "--headless=new", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--remote-debugging-port=9333",
    "--window-size=1600,900", "--no-first-run", "--user-data-dir=" + prof, "about:blank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    for _ in range(50):
        try:
            tabs = json.load(urllib.request.urlopen("http://127.0.0.1:9333/json", timeout=2)); break
        except Exception: time.sleep(0.3)
    ws = websocket.create_connection(next(t for t in tabs if t["type"] == "page")["webSocketDebuggerUrl"], timeout=60)
    n = [0]
    logs = []
    def cmd(method, **params):
        n[0] += 1; ws.send(json.dumps({"id": n[0], "method": method, "params": params}))
        while True:
            m = json.loads(ws.recv())
            if m.get("method") == "Runtime.consoleAPICalled":
                logs.append(" ".join(str(x.get("value", x.get("description", ""))) for x in m["params"]["args"]))
            elif m.get("method") == "Runtime.exceptionThrown":
                logs.append("EXCEPTION " + json.dumps(m["params"]["exceptionDetails"])[:400])
            if m.get("id") == n[0]: return m.get("result", {})
    def pump(sec):
        end = time.time() + sec
        ws.settimeout(0.5)
        while time.time() < end:
            try:
                m = json.loads(ws.recv())
                if m.get("method") == "Runtime.consoleAPICalled":
                    logs.append(" ".join(str(x.get("value", x.get("description", ""))) for x in m["params"]["args"]))
                elif m.get("method") == "Runtime.exceptionThrown":
                    logs.append("EXCEPTION " + json.dumps(m["params"]["exceptionDetails"])[:400])
            except websocket.WebSocketTimeoutException: pass
        ws.settimeout(60)
    def shot(path):
        data = cmd("Page.captureScreenshot", format="png")["data"]
        open(os.path.join(ROOT, path), "wb").write(base64.b64decode(data)); print("screenshot", path)
    cmd("Runtime.enable"); cmd("Page.enable")
    cmd("Emulation.setDeviceMetricsOverride", width=1600, height=900, deviceScaleFactor=1, mobile=False)
    t0 = time.time()
    cmd("Page.navigate", url=(a.url + a.query) if a.url else "http://127.0.0.1:%d/index.html%s" % (port, a.query))
    pump(a.wait)
    shot(a.out)
    if a.idb:  # list what the game persisted (Godot's user:// lives in IndexedDB "/userfs")
        js = """(async () => { const out = {}; for (const d of await indexedDB.databases()) {
            const db = await new Promise((ok, err) => { const q = indexedDB.open(d.name); q.onsuccess = () => ok(q.result); q.onerror = err; });
            for (const st of db.objectStoreNames) out[d.name + ":" + st] = (await new Promise(ok => {
                const q = db.transaction(st).objectStore(st).getAllKeys(); q.onsuccess = () => ok(q.result); })).map(String); }
            return JSON.stringify(out); })()"""
        print("IDB", cmd("Runtime.evaluate", expression=js, awaitPromise=True, returnByValue=True).get("result", {}).get("value"))
    for c in a.click:
        x, y = map(float, c.split(","))
        for typ in ("mousePressed", "mouseReleased"):
            cmd("Input.dispatchMouseEvent", type=typ, x=x, y=y, button="left", clickCount=1)
        pump(1.0)
    if a.click:
        pump(a.wait2)
        shot(a.out2)
    print("--- console (%d lines) ---" % len(logs))
    for l in logs[-40:]: print(l[:300])
finally:
    proc.kill(); srv.shutdown()
