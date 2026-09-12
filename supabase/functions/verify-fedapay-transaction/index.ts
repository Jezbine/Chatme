// verify-fedapay-transaction - Edge Function sécurisée P1.1
// Doit INTERROGER FedaPay côté serveur (GET /transactions/{id}) et créditer atomiquement
// Jamais faire confiance au client. Idempotent (double-crédit impossible).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const FEDA_API_KEY = Deno.env.get("FEDA_API_KEY") || Deno.env.get("FEDAPAY_SECRET_KEY") || "";
const envConfig = (Deno.env.get("FEDA_ENV") ?? "").toLowerCase();
const isLive = envConfig === "live" || FEDA_API_KEY.startsWith("sk_live_");
const FEDA_BASE = isLive ? "https://api.fedapay.com/v1" : "https://sandbox-api.fedapay.com/v1";

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
  const txObj = feda?.["v1/transaction"] ?? feda?.transaction ?? feda;
  const status = txObj?.status;
  // FedaPay statuses: approved, pending, canceled - seul approved crédite
  if (status !== "approved") {
    return new Response(JSON.stringify({ status, credited: false }), { status: 200 });
  }
  const fedaAmount = txObj?.amount;
  if (Number(fedaAmount) !== Number(amount)) {
    return new Response(JSON.stringify({ error: "Amount mismatch", fedaAmount, amount }), { status: 400 });
  }

  // 2. Vérifier si la transaction a déjà été créditée (idempotence par label contenant l'ID FedaPay)
  const label = `Recharge FedaPay #${transaction_id}`;
  const { data: existing } = await supabase
    .from("wallet_transactions")
    .select("id")
    .eq("label", label)
    .maybeSingle();

  if (existing) {
    const { data: balRow } = await supabase
      .from("wallet_balances")
      .select("balance_cents")
      .eq("user_id", user.id)
      .maybeSingle();
    return new Response(
      JSON.stringify({
        status: "already_processed",
        credited: false,
        balance_cents: balRow?.balance_cents ?? 0,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  }

  // 3. Créditer atomiquement via RPC wallet_deposit (qui met à jour le solde et insère la transaction)
  const { data: newBalance, error } = await supabase.rpc("wallet_deposit", {
    p_amount: amount,
    p_label: label,
  });
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({ status: "completed", credited: true, balance_cents: newBalance }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
});
