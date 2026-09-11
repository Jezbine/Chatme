// create-call-token — Edge Function LiveKit P0
// Génère un token LiveKit vérifié côté serveur (participant = auth.uid)
// Déployer: supabase functions deploy create-call-token
// Secrets requis: LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const LIVEKIT_URL = Deno.env.get("LIVEKIT_URL") ?? "";
const LIVEKIT_API_KEY = Deno.env.get("LIVEKIT_API_KEY") ?? "";
const LIVEKIT_API_SECRET = Deno.env.get("LIVEKIT_API_SECRET") ?? "";

function base64UrlEncode(str: string): string {
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
async function hmacSha256(key: string, msg: string): Promise<string> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey("raw", enc.encode(key), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(msg));
  return base64UrlEncode(String.fromCharCode(...new Uint8Array(sig)));
}

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return new Response(JSON.stringify({ error: "Missing Authorization" }), { status: 401 });
  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET || !LIVEKIT_URL) {
    return new Response(JSON.stringify({ error: "LiveKit non configuré côté serveur (LIVEKIT_URL/KEY/SECRET manquants)" }), { status: 503 });
  }
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });

  const { room_name, user_id, user_name } = await req.json();
  if (!room_name || !user_id) return new Response(JSON.stringify({ error: "Missing room_name or user_id" }), { status: 400 });
  if (user_id !== user.id) return new Response(JSON.stringify({ error: "user_id mismatch" }), { status: 403 });

  // Vérifier que user est participant de la conversation call_<convId>
  const convId = (room_name as string).startsWith("call_") ? (room_name as string).slice(5) : null;
  if (convId) {
    const { data: isParticipant } = await supabase.from("conversation_participants").select("user_id").eq("conversation_id", convId).eq("user_id", user.id).maybeSingle();
    if (!isParticipant) return new Response(JSON.stringify({ error: "Non participant de cette conversation" }), { status: 403 });
  }

  // Construire JWT LiveKit (header.payload.signature) — AccessToken simplifié
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = base64UrlEncode(JSON.stringify({
    iss: LIVEKIT_API_KEY,
    sub: user.id,
    name: user_name ?? user.email ?? "Utilisateur",
    iat: now,
    nbf: now,
    exp: now + 3600,
    video: { room: room_name, roomJoin: true, canPublish: true, canSubscribe: true, canPublishData: true },
  }));
  const toSign = `${header}.${payload}`;
  const sig = await hmacSha256(LIVEKIT_API_SECRET, toSign);
  // LiveKit attend base64url sans padding
  const token = `${toSign}.${sig}`;

  return new Response(JSON.stringify({ token, url: LIVEKIT_URL }), { status: 200, headers: { "Content-Type": "application/json" } });
});
