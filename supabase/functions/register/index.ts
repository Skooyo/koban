// POST {"inviteCode": "K7QX-M2PA"} -> 200 {"deviceToken": "..."} | 400 | 403 | 429.
// The token is shown once; the database keeps only its SHA-256.
import { json, rpc, sha256Hex } from "../_shared/db.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "use POST" });
  let code = "";
  try {
    code = String((await req.json()).inviteCode ?? "");
  } catch {
    return json(400, { error: "send JSON {\"inviteCode\": \"XXXX-XXXX\"}" });
  }
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "?";
  const token = Array.from(crypto.getRandomValues(new Uint8Array(32)))
    .map((b) => b.toString(16).padStart(2, "0")).join("");
  const result = await rpc<string>("register_device", {
    p_code: code, p_token_hash: await sha256Hex(token), p_ip: ip,
  });
  switch (result) {
    case "ok": return json(200, { deviceToken: token });
    case "malformed": return json(400, { error: "the invite code looks like XXXX-XXXX" });
    case "too_many": return json(429, { error: "too many attempts" }, { "Retry-After": "3600" });
    default: return json(403, { error: "invite code not accepted" }); // unknown, cancelled or full: one message
  }
});
