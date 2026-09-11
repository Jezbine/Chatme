# Travail Supabase — 2026-09-10 (exécuté)

## Vérifications REST (publishable key)
- `curl -H apikey: sb_publishable_... /rest/v1/profiles?select=id` → `200 []` (table vide, existe)
- `curl /rest/v1/conversations` → `200 []`
- `curl /rest/v1/messages` → `200 []`
- `curl /storage/v1/bucket` → `200 []` **→ aucun bucket, chat-media manquant (bloquant upload)**
- `curl POST /rpc/wallet_deposit` → `400 Non authentifié` → fonction existe, exige auth (OK)
- `curl POST /functions/v1/verify-fedapay-transaction` → `400 Missing transaction_id` → déployée OK (DIAGNOSTIC.md:56)
- `curl POST /functions/v1/create-call-token` → `503 BOOT_ERROR` → déployée mais crash secrets LiveKit manquants (DIAGNOSTIC.md:58)

## Correctifs apportés (fichiers)
- `supabase/SUPABASE_BLOQUANTS_FIX.sql` : script consolidé idempotent couvrant :
  - `mark_messages_as_read(p_conversation_id,p_message_id)` fix 42702 + wrapper
  - bucket `chat-media` privé + 4 policies storage
  - `profiles.fcm_token` + RLS profiles
  - RLS conversations/participants/messages (sécurisé)
  - wallet_balances/wallet_transactions + RPC `wallet_deposit/withdraw/transfer` + `get_or_create_direct_conversation`
  - contact_requests + accept_contact_request
  - statuses/moments + realtime publications
- `supabase/functions/create-call-token/index.ts` (nouveau) : JWT LiveKit avec vérif participant + HMAC SHA256
- `supabase/functions/verify-fedapay-transaction/index.ts` : déjà présent, vérif côté serveur + idempotence

## Actions à faire côté Dashboard (service_role requis)
Anon ne peut pas DDL → exécuter dans SQL Editor :

```sql
-- Copier-coller TOUT supabase/SUPABASE_BLOQUANTS_FIX.sql → RUN
-- Vérifs :
select * from storage.buckets; -- doit voir chat-media
select proname from pg_proc where proname in ('wallet_deposit','wallet_transfer','mark_messages_as_read');
select * from pg_policies where tablename='messages';
```

Puis Edge Functions :
```
supabase functions deploy verify-fedapay-transaction
supabase functions deploy create-call-token
supabase secrets set FEDA_API_KEY=pk_live_xxx FEDA_ENV=live LIVEKIT_URL=wss://xxx.livekit.cloud LIVEKIT_API_KEY=xxx LIVEKIT_API_SECRET=xxx --project-ref zunviylosliunknpneph
```

Dashboard > Auth > URL Configuration :
- Site URL : `io.supabase.chatme://login-callback/`
- Redirect URLs : `io.supabase.chatme://login-callback/`, `chatme://auth/callback`, `https://zunviylosliunknpneph.supabase.co/auth/v1/callback`

Après ça : `flutter run --dart-define=SUPABASE_URL=https://zunviylosliunknpneph.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_mG2qOXX7Dzi4ZCxfDNZs3w_VUuqYiJt`
