import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const ALLOWED_ORIGINS = new Set([
  "https://infotelcom.github.io",
  "http://localhost:5173",
  "http://127.0.0.1:5173",
]);

function corsHeaders(req: Request) {
  const origin = req.headers.get("origin");
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  // Server-to-server webhook calls normally have no Origin header.
  if (origin && ALLOWED_ORIGINS.has(origin)) headers["Access-Control-Allow-Origin"] = origin;
  return headers;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  const cors = corsHeaders(req);
  if (req.method === "OPTIONS") {
    const origin = req.headers.get("origin");
    if (origin && !ALLOWED_ORIGINS.has(origin)) {
      return new Response("Origin not allowed", { status: 403, headers: cors });
    }
    return new Response(null, { status: 204, headers: cors });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: cors });
  }

  const origin = req.headers.get("origin");
  if (origin && !ALLOWED_ORIGINS.has(origin)) {
    return new Response("Origin not allowed", { status: 403, headers: cors });
  }

  const expected = Deno.env.get("PUSH_WEBHOOK_SECRET");
  const supplied = req.headers.get("x-webhook-secret");
  if (!expected || !supplied || supplied !== expected) {
    return new Response("Unauthorized", { status: 401, headers: cors });
  }
  if (!req.headers.get("content-type")?.toLowerCase().includes("application/json")) {
    return new Response("Content-Type must be application/json", { status: 415, headers: cors });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const publicKey = Deno.env.get("VAPID_PUBLIC_KEY");
  const privateKey = Deno.env.get("VAPID_PRIVATE_KEY");
  const subject = Deno.env.get("VAPID_SUBJECT") || "mailto:contact.infotelcom@gmail.com";
  if (!url || !serviceKey || !publicKey || !privateKey) {
    return new Response("Push secrets are not configured", { status: 503, headers: cors });
  }

  try {
    const event = await req.json();
    const row = event?.record && typeof event.record === "object" ? event.record : event;
    if (!row || typeof row !== "object" || typeof row.user_id !== "string" || !UUID_RE.test(row.user_id)) {
      return new Response("A valid user_id is required", { status: 400, headers: cors });
    }

    const db = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: subs, error } = await db
      .from("connect_push_subscriptions")
      .select("id,endpoint,subscription")
      .eq("user_id", row.user_id);
    if (error) throw error;

    webpush.setVapidDetails(subject, publicKey, privateKey);
    const appUrl = new URL("https://infotelcom.github.io/INFOTELCOM-Connect/");
    if (typeof row.channel_id === "string" && UUID_RE.test(row.channel_id)) {
      appUrl.searchParams.set("channel", row.channel_id);
    }
    if (typeof row.message_id === "string" && UUID_RE.test(row.message_id)) {
      appUrl.searchParams.set("message", row.message_id);
    }

    const payload = JSON.stringify({
      title: typeof row.title === "string" ? row.title.slice(0, 120) : "INFOTELCOM Connect",
      body: typeof row.body === "string" ? row.body.slice(0, 500) : "Nouvelle activité",
      url: appUrl.toString(),
      tag: typeof row.id === "string" ? row.id.slice(0, 128) : "connect-notification",
    });

    const results = await Promise.all((subs || []).map(async (s) => {
      try {
        await webpush.sendNotification(s.subscription, payload);
        return { ok: true };
      } catch (e) {
        const status = Number(e?.statusCode) || 500;
        if (status === 404 || status === 410) {
          await db.from("connect_push_subscriptions").delete().eq("id", s.id);
        }
        return { ok: false, status };
      }
    }));

    return new Response(JSON.stringify({
      delivered: results.filter((x) => x.ok).length,
      attempted: results.length,
    }), { status: 200, headers: { ...cors, "Content-Type": "application/json" } });
  } catch {
    // Avoid returning database/provider details to an external caller.
    return new Response(JSON.stringify({ error: "Unable to process push notification" }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
