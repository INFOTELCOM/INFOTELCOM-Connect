import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret", "Access-Control-Allow-Methods": "POST, OPTIONS" };
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: cors });
  const expected = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (!expected || req.headers.get("x-webhook-secret") !== expected) return new Response("Unauthorized", { status: 401, headers: cors });
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const publicKey = Deno.env.get("VAPID_PUBLIC_KEY");
  const privateKey = Deno.env.get("VAPID_PRIVATE_KEY");
  const subject = Deno.env.get("VAPID_SUBJECT") || "mailto:contact.infotelcom@gmail.com";
  if (!url || !serviceKey || !publicKey || !privateKey) return new Response("Push secrets are not configured", { status: 503, headers: cors });
  try {
    const event = await req.json();
    const row = event.record || event;
    if (!row.user_id) return new Response("Missing user_id", { status: 400, headers: cors });
    const db = createClient(url, serviceKey);
    const { data: subs, error } = await db.from("connect_push_subscriptions").select("id,endpoint,subscription").eq("user_id", row.user_id);
    if (error) throw error;
    webpush.setVapidDetails(subject, publicKey, privateKey);
    const payload = JSON.stringify({ title: row.title || "INFOTELCOM Connect", body: row.body || "Nouvelle activité", url: row.channel_id ? "/?channel=" + encodeURIComponent(row.channel_id) : "/", tag: row.id || "connect-notification" });
    const results = await Promise.all((subs || []).map(async (s) => {
      try { await webpush.sendNotification(s.subscription, payload); return { ok: true }; }
      catch (e) { if (e.statusCode === 404 || e.statusCode === 410) await db.from("connect_push_subscriptions").delete().eq("id", s.id); return { ok: false, status: e.statusCode || 500 }; }
    }));
    return new Response(JSON.stringify({ delivered: results.filter(x => x.ok).length, attempted: results.length }), { status: 200, headers: { ...cors, "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error?.message || error) }), { status: 500, headers: { ...cors, "Content-Type": "application/json" } });
  }
});
