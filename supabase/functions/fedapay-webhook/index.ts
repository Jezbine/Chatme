// fedapay-webhook - Edge Function Supabase pour écouter les notifications FedaPay Live
// Traite les événements de paiement validé (transaction.approved)
// Vérifie toujours auprès de FedaPay Live (anti-spoofing) et crédite atomiquement le portefeuille

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const FEDA_API_KEY = Deno.env.get("FEDA_API_KEY") || Deno.env.get("FEDAPAY_SECRET_KEY") || "";
const envConfig = (Deno.env.get("FEDA_ENV") ?? "live").toLowerCase();
const isLive = envConfig !== "sandbox";
const FEDA_BASE = isLive ? "https://api.fedapay.com/v1" : "https://sandbox-api.fedapay.com/v1";

serve(async (req) => {
  // Seul POST est accepté pour les webhooks
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const payload = await req.json();
    console.log("[FedaPay Webhook] Événement reçu:", payload?.name || payload?.event);

    // Extraction de l'objet transaction
    // FedaPay transmet soit l'événement sous forme { name: "transaction.approved", entity: { ... } }
    // ou directement { entity: { ... } } ou { transaction: { ... } }
    const eventName = payload?.name || payload?.event || "";
    const entity = payload?.entity || payload?.["v1/transaction"] || payload?.transaction || payload;
    const txId = entity?.id;

    if (!txId) {
      return new Response(JSON.stringify({ error: "Transaction ID missing from webhook payload" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 1. SÉCURITÉ ABSOLUE : Interrogation directe de l'API FedaPay Live pour vérifier la transaction
    // Ne jamais faire confiance aveuglément au corps de la requête du webhook (protection contre le spoofing)
    const fedaRes = await fetch(`${FEDA_BASE}/transactions/${txId}`, {
      headers: {
        Authorization: `Bearer ${FEDA_API_KEY}`,
        "Content-Type": "application/json",
      },
    });

    if (!fedaRes.ok) {
      const errText = await fedaRes.text();
      console.error("[FedaPay Webhook] Échec récupération transaction FedaPay:", errText);
      return new Response(JSON.stringify({ error: "Cannot verify transaction with FedaPay", details: errText }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    const fedaData = await fedaRes.json();
    const verifiedTx = fedaData?.["v1/transaction"] ?? fedaData?.transaction ?? fedaData;
    const status = verifiedTx?.status;
    const amount = Number(verifiedTx?.amount);
    const customMetadata = verifiedTx?.custom_metadata;

    console.log(`[FedaPay Webhook] Transaction #${txId} statut vérifié: ${status}, montant: ${amount}`);

    // Si la transaction n'est pas encore approuvée, on acquitte la réception sans créditer
    if (status !== "approved") {
      return new Response(JSON.stringify({ message: `Transaction status is ${status}, no credit applied` }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2. Récupération du user_id ChatMe
    let userId = customMetadata?.user_id;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Si le user_id n'était pas dans les métadonnées, tentative de résolution via le numéro client
    if (!userId) {
      const customerPhone = verifiedTx?.customer?.phone_number?.number;
      if (customerPhone) {
        // Recherche dans profiles
        const { data: prof } = await supabase
          .from("profiles")
          .select("id")
          .or(`phone.ilike.%${customerPhone}%,phone_number.ilike.%${customerPhone}%`)
          .maybeSingle();
        if (prof?.id) {
          userId = prof.id;
        }
      }
    }

    if (!userId) {
      console.warn(`[FedaPay Webhook] Impossible de rattacher la transaction #${txId} à un utilisateur ChatMe`);
      return new Response(JSON.stringify({ error: "User not found for this transaction", txId }), {
        status: 422,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3. IDEMPOTENCE : Vérifier si la transaction a déjà été créditée
    const txLabel = `Recharge FedaPay #${txId}`;
    const { data: existingTx } = await supabase
      .from("wallet_transactions")
      .select("id")
      .eq("label", txLabel)
      .maybeSingle();

    if (existingTx) {
      console.log(`[FedaPay Webhook] Transaction #${txId} déjà créditée (idempotence).`);
      return new Response(JSON.stringify({ status: "already_processed", credited: false, txId }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 4. CRÉDITER LE SOLDE DE L'UTILISATEUR
    // A) Mettre à jour le solde dans wallet_balances
    const { data: currentBalRow } = await supabase
      .from("wallet_balances")
      .select("balance_cents")
      .eq("user_id", userId)
      .maybeSingle();

    const previousBalance = currentBalRow?.balance_cents ?? 0;
    const newBalance = previousBalance + amount;

    const { error: balError } = await supabase
      .from("wallet_balances")
      .upsert({
        user_id: userId,
        balance_cents: newBalance,
        updated_at: new Date().toISOString(),
      });

    if (balError) {
      console.error("[FedaPay Webhook] Erreur mise à jour wallet_balances:", balError);
      return new Response(JSON.stringify({ error: balError.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    // B) Insérer l'historique dans wallet_transactions
    const { error: txError } = await supabase
      .from("wallet_transactions")
      .insert({
        user_id: userId,
        label: txLabel,
        amount_cents: amount,
        status: "completed",
      });

    if (txError) {
      console.error("[FedaPay Webhook] Erreur insertion wallet_transactions:", txError);
    }

    console.log(`[FedaPay Webhook] Succès : +${amount} FCFA crédités pour l'utilisateur ${userId}. Nouveau solde: ${newBalance} FCFA.`);

    return new Response(
      JSON.stringify({
        success: true,
        credited: true,
        transaction_id: txId,
        user_id: userId,
        new_balance: newBalance,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("[FedaPay Webhook] Erreur inattendue:", err);
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

