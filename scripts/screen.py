#!/usr/bin/env python3
"""
Serves the Mac's console screen as a web page, and sends clicks and keystrokes
back to it. Needs no macOS account login — it uses screencapture and cliclick,
both of which work as the console user, so Apple's screen-sharing lockout
doesn't apply.

  brew install cliclick
  python3 screen.py 6090
"""
import http.server, socketserver, subprocess, threading, json, sys, os, time

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 6090
SHOT = "/tmp/_screen.jpg"

# screencapture returns retina pixels; cliclick works in points. Get both.
def screen_points():
    try:
        out = subprocess.run(
            ["osascript", "-e", 'tell application "Finder" to get bounds of window of desktop'],
            capture_output=True, text=True, timeout=10).stdout.strip()
        parts = [int(x.strip()) for x in out.split(",")]
        return parts[2], parts[3]
    except Exception:
        return 0, 0

PW, PH = screen_points()

PAGE = """<!doctype html><html><head><meta charset=utf-8>
<title>mac</title><style>
 html,body{margin:0;background:#111;height:100%%;overflow:hidden}
 #s{width:100%%;height:100%%;object-fit:contain;display:block;cursor:crosshair}
 #b{position:fixed;top:0;left:0;right:0;background:#000c;color:#eee;
    font:12px ui-monospace,monospace;padding:4px 8px;z-index:9}
</style></head><body>
<div id=b>click to move+click &middot; type to send keys &middot; screen %dx%d</div>
<img id=s src="/shot.jpg">
<script>
const img = document.getElementById('s');
let n = 0;
function tick(){ const i = new Image();
  i.onload = () => { img.src = i.src; setTimeout(tick, 250); };
  i.onerror = () => setTimeout(tick, 1000);
  i.src = '/shot.jpg?' + (n++); }
tick();
function send(o){fetch('/input',{method:'POST',body:JSON.stringify(o)});}
img.addEventListener('click', e => {
  const r = img.getBoundingClientRect();
  // the image is object-fit:contain, so work out the real drawn box
  const ar = img.naturalWidth / img.naturalHeight;
  let w = r.width, h = r.width / ar;
  if (h > r.height) { h = r.height; w = r.height * ar; }
  const ox = r.left + (r.width - w) / 2, oy = r.top + (r.height - h) / 2;
  const x = (e.clientX - ox) / w, y = (e.clientY - oy) / h;
  if (x < 0 || x > 1 || y < 0 || y > 1) return;
  send({t:'click', x:x, y:y});
});
document.addEventListener('keydown', e => {
  e.preventDefault();
  const named = {Enter:'return', Backspace:'delete', Tab:'tab', Escape:'esc',
                 ArrowUp:'arrow-up', ArrowDown:'arrow-down',
                 ArrowLeft:'arrow-left', ArrowRight:'arrow-right', ' ':'space'};
  if (named[e.key]) send({t:'key', k:named[e.key]});
  else if (e.metaKey && e.key.length === 1) send({t:'cmd', k:e.key});
  else if (e.key.length === 1) send({t:'type', s:e.key});
});
</script></body></html>""" % (PW, PH)


def grab():
    subprocess.run(["screencapture", "-x", "-t", "jpg", "-C", SHOT],
                   capture_output=True, timeout=20)
    try:
        with open(SHOT, "rb") as f:
            return f.read()
    except OSError:
        return b""


class H(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def do_GET(self):
        if self.path == "/":
            body = PAGE.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if self.path.startswith("/shot.jpg"):
            jpg = grab()
            self.send_response(200 if jpg else 503)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(jpg)))
            self.end_headers()
            self.wfile.write(jpg)
            return

        if self.path == "/stream":
            self.send_response(200)
            self.send_header("Content-Type",
                             "multipart/x-mixed-replace; boundary=f")
            self.end_headers()
            try:
                while True:
                    jpg = grab()
                    if jpg:
                        self.wfile.write(b"--f\r\nContent-Type: image/jpeg\r\n"
                                         b"Content-Length: %d\r\n\r\n" % len(jpg))
                        self.wfile.write(jpg)
                        self.wfile.write(b"\r\n")
                    time.sleep(0.4)
            except (BrokenPipeError, ConnectionResetError):
                return
        self.send_error(404)

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        try:
            o = json.loads(self.rfile.read(n) or b"{}")
        except ValueError:
            o = {}
        try:
            if o.get("t") == "click" and PW:
                x, y = int(o["x"] * PW), int(o["y"] * PH)
                subprocess.run(["cliclick", "c:%d,%d" % (x, y)], timeout=10)
            elif o.get("t") == "key":
                subprocess.run(["cliclick", "kp:" + o["k"]], timeout=10)
            elif o.get("t") == "cmd":
                subprocess.run(["cliclick", "kd:cmd", "t:" + o["k"], "ku:cmd"], timeout=10)
            elif o.get("t") == "type":
                subprocess.run(["cliclick", "t:" + o["s"]], timeout=10)
        except Exception as e:
            print("input failed:", e, file=sys.stderr)
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self.end_headers()


class S(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


print("screen %dx%d points, serving on %d" % (PW, PH, PORT), flush=True)
S(("127.0.0.1", PORT), H).serve_forever()
