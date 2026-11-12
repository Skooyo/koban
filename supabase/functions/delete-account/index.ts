// POST with the person's session ("Authorization: Bearer <access token>") -> 204.
// Deletes the auth user; `on delete cascade` removes the profile, memberships, shared totals and budget limits.
// See docs/superpowers/specs/2026-11-12-group-tracker-design.md, section 2.
import { json } from "../_shared/db.ts";

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "use POST" });
  const auth = req.headers.get("authorization") ?? "";
  const who = await fetch(`${URL}/auth/v1/user`, { headers: { apikey: KEY, Authorization: auth } });
  if (!who.ok) return json(401, { error: "sign in again" });
  const { id } = await who.json();
  const del = await fetch(`${URL}/auth/v1/admin/users/${id}`, {
    method: "DELETE",
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
  });
  if (!del.ok) {
    console.error("delete user failed", del.status);
    return json(500, { error: "could not delete the account" });
  }
  return new Response(null, { status: 204 });
});
