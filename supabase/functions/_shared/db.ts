// Shared helpers for Koban's Edge Functions. The database functions live in supabase/migrations.

const URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

/** Calls a Postgres function through PostgREST with the service role (bypasses RLS). */
export async function rpc<T>(name: string, args: Record<string, unknown>): Promise<T> {
  const r = await fetch(`${URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(args),
  });
  if (!r.ok) throw new Error(`rpc ${name}: ${r.status} ${await r.text()}`);
  const text = await r.text(); // a void function answers 204 with no body
  return (text ? JSON.parse(text) : null) as T;
}

export async function sha256Hex(text: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(d)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function json(status: number, body: unknown, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...headers } });
}
