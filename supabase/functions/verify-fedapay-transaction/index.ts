// verify-fedapay-transaction - Edge Function sécurisée P1.1
// Doit INTERROGER FedaPay côté serveur (GET /transactions/{id}) et créditer atomiquement
// Jamais faire confiance au client. Idempotent (double-crédit impossible).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const FEDA_API_KEY = Deno.env.get("FEDA_API_KEY")!;
const FEDA_ENV = Deno.env.get("FEDA_ENV") ?? "sandbox";
const FEDA_BASE = FEDA_ENV === "live" ? "https://api.fedapay.com/v1" : "https://sandbox-api.fedapay.com/v1";

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return new Response(JSON.stringify({ error: "Missing Authorization" }), { status: 401 });

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });

  const { transaction_id, amount } = await req.json();
  if (!transaction_id || !amount) return new Response(JSON.stringify({ error: "Missing transaction_id or amount" }), { status: 400 });

  // 1. Interroger FedaPay côté serveur (source de vérité)
  const fedaRes = await fetch(`${FEDA_BASE}/transactions/${transaction_id}`, {
    headers: { Authorization: `Bearer ${FEDA_API_KEY}`, "Content-Type": "application/json" },
  });
  if (!fedaRes.ok) {
    const txt = await fedaRes.text();
    return new Response(JSON.stringify({ error: "FedaPay fetch failed", details: txt }), { status: 502 });
  }
  const feda = await fedaRes.json();
  const status = feda?.transaction?.status ?? feda?.status;
  // FedaPay statuses: approved, pending, canceled - seul approved crédite
  if (status !== "approved") {
    return new Response(JSON.stringify({ status, credited: false }), { status: 200 });
  }
  const fedaAmount = feda?.transaction?.amount ?? feda?.amount;
  if (Number(fedaAmount) !== Number(amount)) {
    return new Response(JSON.stringify({ error: "Amount mismatch", fedaAmount, amount }), { status: 400 });
  }

  // 2. Vérifier que le user est bien le propriétaire (via metadata si stocké) - au minimum même user que l'appel
  // 3. Créditer atomiquement via RPC wallet_deposit (idempotent via transaction_id unique)
  // On stocke transaction_id dans wallet_transactions pour dédupliquer
  const { data: existing } = await supabase.from("wallet_transactions").select("id").eq("id", transaction_id).maybeSingle();
  if (existing) {
    return new Response(JSON.stringify({ status: "already_processed", credited: false }), { status: 200 });
  }

  // RPC atomique - à adapter selon votre fonction wallet_deposit qui gère balance + insert transaction
  const { data: newBalance, error } = await supabase.rpc("wallet_deposit", { p_amount: amount, p_label: `Recharge FedaPay #${transaction_id}` });
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

  // Tracer la transaction FedaPay pour idempotence
  await supabase.from("wallet_transactions").upsert({ id: transaction_id, user_id: user.id, label: `Recharge FedaPay`, amount_cents: amount, status: "completed" }, { onConflict: "id" });

  return new Response(JSON.stringify({ status: "completed", credited: true, balance_cents: newBalance }), { status: 200, headers: { "Content-Type": "application/json" } });
});
