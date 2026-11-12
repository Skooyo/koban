// POST raw JPEG/PNG with "Authorization: Bearer <deviceToken>" -> 200 receipt JSON + readsLeftToday.
// Checks the device and the daily limits, then forwards the photo to the receipt service on the owner's server.
// A read counts only when Claude ran (200, 502, 504). See docs/superpowers/specs/2026-11-12-receipt-claude-fallback-design.md.
import { json, rpc, sha256Hex } from "../_shared/db.ts";

const SERVICE_URL = Deno.env.get("RECEIPT_SERVICE_URL")!;
const SERVICE_TOKEN = Deno.env.get("RECEIPT_SERVICE_TOKEN")!;
const MAX_BYTES = 2 * 1024 * 1024;
const TYPES = new Set(["image/jpeg", "image/png"]);

type Reservation = { ok: boolean; reason?: string; read_id?: number; reads_left?: number };

/** Seconds until the next midnight in Malaysia (UTC+8), when the daily limits reset. */
function secondsToMidnightMyt(): number {
  const now = Date.now() + 8 * 3600_000;
  return Math.ceil((86_400_000 - (now % 86_400_000)) / 1000);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "use POST" });
  const token = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return json(401, { error: "no device token" });
  const type = (req.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
  if (!TYPES.has(type)) return json(415, { error: "send image/jpeg or image/png" });
  if (Number(req.headers.get("content-length") ?? "0") > MAX_BYTES) return json(413, { error: "photo must be 2 MB or less" });
  const photo = new Uint8Array(await req.arrayBuffer());
  if (photo.length === 0 || photo.length > MAX_BYTES) return json(413, { error: "photo must be 1 byte to 2 MB" });

  const hash = await sha256Hex(token);
  const r = await rpc<Reservation>("reserve_read", { p_token_hash: hash });
  if (!r.ok) {
    if (r.reason === "unknown") return json(401, { error: "device token not accepted" });
    return json(429, { error: "daily limit reached", limit: r.reason }, { "Retry-After": String(secondsToMidnightMyt()) });
  }

  let res: Response;
  try {
    res = await fetch(SERVICE_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${SERVICE_TOKEN}`, "Content-Type": type, "X-Device": hash.slice(0, 8) },
      body: photo,
      signal: AbortSignal.timeout(70_000),
    });
  } catch (e) {
    const timedOut = e instanceof DOMException && e.name === "TimeoutError";
    await rpc("finish_read", { p_read_id: r.read_id, p_status: timedOut ? "failed" : "released" });
    return timedOut ? json(504, { error: "timeout" }) : json(503, { error: "reader not reachable" }, { "Retry-After": "60" });
  }

  if (res.status === 200) {
    const receipt = await res.json();
    await rpc("finish_read", { p_read_id: r.read_id, p_status: "ok" });
    return json(200, { ...receipt, readsLeftToday: r.reads_left });
  }
  if (res.status === 502 || res.status === 504) {
    await rpc("finish_read", { p_read_id: r.read_id, p_status: "failed" });
    return json(res.status, { error: res.status === 502 ? "could not read" : "timeout" });
  }
  await rpc("finish_read", { p_read_id: r.read_id, p_status: "released" }); // Claude did not run: the read is free
  if (res.status === 503) return json(503, { error: "busy" }, { "Retry-After": res.headers.get("retry-after") ?? "60" });
  console.error("receipt service answered", res.status); // 401/413/415 here means a setup fault, not the friend's
  return json(500, { error: "server setup fault" });
});
