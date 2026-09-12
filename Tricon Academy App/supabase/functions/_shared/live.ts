// Server-only code. Do not bundle these files in the iOS app.
export function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing server setting: ${name}`);
  return value;
}
export function response(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}
export async function db(path: string, token: string, init: RequestInit = {}) {
  const result = await fetch(`${env("SUPABASE_URL")}/rest/v1/${path}`, {
    ...init,
    headers: { apikey: env("SUPABASE_ANON_KEY"), Authorization: `Bearer ${token}`, "Content-Type": "application/json", ...init.headers },
  });
  if (!result.ok) throw new Error(`Database request failed (${result.status})`);
  const text = await result.text();
  return text ? JSON.parse(text) : null;
}
export async function authorize(request: Request) {
  if (request.method !== "POST") throw new Error("POST required");
  const bearer = request.headers.get("Authorization") ?? "";
  if (!bearer.startsWith("Bearer ")) throw new Error("Authentication required");
  const token = bearer.slice(7);
  const result = await fetch(`${env("SUPABASE_URL")}/auth/v1/user`, {
    headers: { apikey: env("SUPABASE_ANON_KEY"), Authorization: bearer },
  });
  if (!result.ok) throw new Error("Authentication required");
  const user = await result.json();
  const input = await request.json();
  if (typeof input.lesson_id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input.lesson_id)) throw new Error("Invalid lesson ID");
  const lessons = await db(`live_lessons?id=eq.${input.lesson_id}&select=*`, token);
  if (lessons.length !== 1) throw new Error("Lesson unavailable"); // RLS enforces grade, role and account state.
  return { token, user, input, lesson: lessons[0] };
}
export function roomName(id: string) { return `live-${id.toLowerCase()}`; }
