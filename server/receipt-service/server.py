"""Koban receipt reader: photo in, receipt JSON out. Runs `claude -p` (Haiku, then Sonnet once if needed).

Only the Supabase Edge Function calls this service (Bearer RECEIPT_TOKEN). One photo at a time; 5 waiting = 503.
See docs/superpowers/specs/2026-11-12-receipt-claude-fallback-design.md.
"""
import hmac, json, os, re, shutil, subprocess, tempfile, threading, time
from decimal import Decimal, InvalidOperation
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN = os.environ["RECEIPT_TOKEN"].encode()
CLAUDE = os.environ.get("CLAUDE_BIN", "/var/lib/koban-receipt/.local/bin/claude")
PORT = int(os.environ.get("PORT", "8081"))
MAX_BODY = 2 * 1024 * 1024
MAX_WAITING = 5
DEADLINE = 60  # seconds for all Claude work on one photo
TYPES = {"image/jpeg": "jpg", "image/png": "png"}

PROMPT = """Read the image file receipt.{ext} in the current folder. It is a restaurant receipt from Malaysia.
Reply with JSON only, no other text, in this shape:
{{"merchant": string|null, "date": "YYYY-MM-DD"|null, "items": [{{"name": string, "quantity": int, "price": string}}], "serviceCharge": string, "tax": string, "discount": string, "rounding": string, "total": string|null}}
Money values are strings with 2 decimals. "price" is the line total, not the unit price. Use "0.00" for charges that are not printed. If the item prices already include tax, put the tax in "tax" only if the printed total adds it on top."""

run_lock = threading.Lock()
count_lock = threading.Lock()
waiting = 0


def money(v):
    d = Decimal(str(v).replace(",", "").replace("RM", "").strip() or "0")
    return str(d.quantize(Decimal("0.01")))


def clean(raw):
    """Parse Claude's reply into the receipt shape, or None when it is not valid."""
    m = re.search(r"\{.*\}", raw or "", re.S)
    if not m:
        return None
    try:
        j = json.loads(m.group(0))
        items = [{"name": str(i["name"]).strip(), "quantity": max(1, int(i.get("quantity") or 1)), "price": money(i["price"])}
                 for i in j["items"]]
        out = {"merchant": j.get("merchant") or None, "date": j.get("date") or None, "items": items}
        for k in ("serviceCharge", "tax", "discount", "rounding"):
            out[k] = money(j.get(k) or "0")
        out["total"] = money(j["total"]) if j.get("total") not in (None, "") else None
        if out["date"] and not re.fullmatch(r"\d{4}-\d{2}-\d{2}", out["date"]):
            out["date"] = None
        return out
    except (KeyError, TypeError, ValueError, InvalidOperation):
        return None


def adds_up(r):
    if r["total"] is None:
        return False
    s = sum(Decimal(i["price"]) for i in r["items"])
    calc = s + Decimal(r["serviceCharge"]) + Decimal(r["tax"]) - Decimal(r["discount"]) + Decimal(r["rounding"])
    return abs(calc - Decimal(r["total"])) <= Decimal("0.02")


def ask(model, folder, ext, timeout):
    r = subprocess.run(
        [CLAUDE, "-p", "--model", model, "--tools", "Read", "--max-turns", "3",
         "--output-format", "text", "--no-session-persistence"],
        input=PROMPT.format(ext=ext), capture_output=True, text=True, timeout=timeout, cwd=folder)
    return r.stdout if r.returncode == 0 else None


def read_receipt(body, ext):
    """Returns (status, result, model). Status: 200, 502 (no valid JSON) or 504 (too slow)."""
    folder = tempfile.mkdtemp(prefix="receipt-")
    try:
        with open(os.path.join(folder, "receipt." + ext), "wb") as f:
            f.write(body)
        start = time.monotonic()
        try:
            first = clean(ask("haiku", folder, ext, DEADLINE))
        except subprocess.TimeoutExpired:
            return 504, None, "haiku"
        if first and adds_up(first):
            return 200, first, "haiku"
        left = DEADLINE - (time.monotonic() - start)
        if left > 15:
            try:
                second = clean(ask("sonnet", folder, ext, left))
                if second and (adds_up(second) or not first):
                    return 200, second, "sonnet"
            except subprocess.TimeoutExpired:
                pass
        return (200, first, "haiku") if first else (502, None, "haiku")
    finally:
        shutil.rmtree(folder, ignore_errors=True)  # the photo is never kept


class Handler(BaseHTTPRequestHandler):
    timeout = 30

    def send(self, code, obj, headers=()):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        for k, v in headers:
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def log_line(self, **kw):  # status, size, duration, model, device hash only: no photo, no receipt content
        self.log_message("%s", json.dumps(kw))

    def do_POST(self):
        global waiting
        t0 = time.monotonic()
        if self.path != "/receipts/read":
            return self.send(404, {"error": "not found"})
        if not hmac.compare_digest(self.headers.get("Authorization", "").encode(), b"Bearer " + TOKEN):
            return self.send(401, {"error": "unauthorized"})
        ext = TYPES.get((self.headers.get("Content-Type") or "").split(";")[0].strip().lower())
        if not ext:
            return self.send(415, {"error": "send image/jpeg or image/png"})
        try:
            n = int(self.headers["Content-Length"])
        except (TypeError, ValueError):
            return self.send(411, {"error": "length required"})
        if not 0 < n <= MAX_BODY:
            return self.send(413, {"error": "photo must be 2 MB or less"})
        body = self.rfile.read(n)
        device = (self.headers.get("X-Device") or "?")[:8]
        with count_lock:
            if waiting >= MAX_WAITING:
                self.log_line(status=503, size=n, device=device)
                return self.send(503, {"error": "busy"}, [("Retry-After", "60")])
            waiting += 1
        try:
            with run_lock:
                status, result, model = read_receipt(body, ext)
        finally:
            with count_lock:
                waiting -= 1
        self.log_line(status=status, size=n, model=model, device=device, secs=round(time.monotonic() - t0, 1))
        if status == 200:
            return self.send(200, result)
        return self.send(status, {"error": "could not read" if status == 502 else "timeout"})


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
