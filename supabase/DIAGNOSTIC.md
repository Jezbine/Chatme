# Diagnostic Supabase — ChatMe

**URL:** `https://zunviylosliunknpneph.supabase.co`  
**Clé testée:** `sb_publishable_mG2qOXX7Dzi4ZCxfDNZs3w_VUuqYiJt` (anon)  
**Date:** 2026-09-10 14:31 UTC  
**Mode:** anon (publishable) — pas de service_role

---

## 1. Tables — toutes présentes, toutes vides

Test `GET /rest/v1/<table>?limit=1` avec anon key :

| Table | Status | Commentaire |
|-------|--------|-------------|
| `profiles` | 200 `[]` | Colonnes `fcm_token`, `phone_number`, `display_name`, `avatar_url`, `is_online`, `last_seen` OK |
| `conversations` | 200 `[]` | Vide, contrainte `created_by NOT NULL` active |
| `conversation_participants` | 200 `[]` | OK |
| `messages` | 200 `[]` | Colonnes `content`, `type`, `media_url`, `sender_id`, `status` OK |
| `moments` | 200 `[]` | OK |
| `moment_likes` | 200 `[]` | OK |
| `moment_comments` | 200 `[]` | OK |
| `wallet_balances` | 200 `[]` | Colonnes `user_id`, `balance_cents` OK |
| `wallet_transactions` | 200 `[]` | Colonnes `label`, `amount_cents`, `status` OK |
| `statuses` | 200 `[]` | Table s'appelle `statuses` (pas `status`) |

→ Schéma déployé, mais **base vide** (aucune donnée seed). Normal pour premier audit.

---

## 2. RPC — fonctions DB

| Fonction | Appel test | Résultat |
|----------|------------|----------|
| `wallet_deposit(p_amount, p_label)` | `POST /rpc/wallet_deposit {"p_amount":1000}` | `400 Non authentifié` → existe, exige `auth.uid()` ✅ |
| `wallet_withdraw` | idem | `400 Non authentifié` → existe ✅ |
| `wallet_transfer(p_dest_user_id, p_amount)` | `{"p_dest_user_id":"uuid","p_amount":100}` | `400 Non authentifié` → existe ✅ |
| `get_or_create_direct_conversation(other_user_id)` | `{"other_user_id":"uuid"}` | `400 null value in column "created_by" violates not-null` → existe mais **requiert user authentifié**, anon échoue (attendu) |
| `mark_messages_as_read(conversation_id, message_id)` | `{"conversation_id":"uuid","message_id":"uuid"}` | `400 column reference "conversation_id" is ambiguous` → **BUG** ❌ voir fix ci-dessous |

**Action:** corriger `mark_messages_as_read` (paramètre ambigu).

---

## 3. Storage

`GET /storage/v1/bucket` → `200 []` → **aucun bucket**. Le code attend `chat-media` (`lib/services/messaging_service.dart:315` `storage.from('chat-media')`). Upload actuel → `Erreur upload: ... Bucket not found`.

**Action:** créer bucket `chat-media` public + policies.

---

## 4. Edge Functions

| Function | URL | Status |
|----------|-----|--------|
| `verify-fedapay-transaction` | `POST /functions/v1/verify-fedapay-transaction {"test":1}` | `400 Missing transaction_id or user_id` → **déployée et OK** (message attendu quand params manquent) |
| `create-call-token` | `POST /functions/v1/create-call-token` | `503 BOOT_ERROR Function failed to start` → **déployée mais crash au boot** — probablement `LIVEKIT_API_KEY / LIVEKIT_API_SECRET / LIVEKIT_URL` non configurés dans Supabase Vault/Env |

**Action:** configurer secrets LiveKit dans Dashboard > Edge Functions > Secrets, puis redeploy.

---

## 5. Auth

`POST /auth/v1/signup` avec `audit.test123@gmail.com` → `429 over_email_send_rate_limit` → Auth opérationnel, mais rate-limit atteint (trop de tests). `profiles` vide confirme qu'aucun user n'a encore été créé via l'app.

---

## 6. Ce que je ne peux pas faire avec la clé anon

La clé `sb_publishable_*` (anon) ne permet **pas** de :
- exécuter du DDL (`CREATE TABLE`, `ALTER FUNCTION`, `INSERT INTO storage.buckets`)
- lire `pg_proc` / `information_schema` complet
- voir les logs Edge Functions
- créer un bucket storage
- corriger une fonction PL/pgSQL

Pour **travailler directement dans la BD** (corriger `mark_messages_as_read`, créer `chat-media`, vérifier RLS), j'ai besoin de la **service_role key** (`sb_secret_...` ou `eyJ...` avec `role: service_role`). Elle est dans Supabase Dashboard > Project Settings > API Keys > `service_role` (à ne jamais commit).

**Options :**
1. Tu me colles la `service_role` key ici (je l'utilise uniquement en mémoire pour patcher, je ne l'écris nulle part) — je corrige tout en direct.
2. Tu exécutes toi-même les 2 fichiers SQL ci-dessous dans Dashboard > SQL Editor > New Query.

---

## 7. Correctifs fournis

- `supabase/migrations/001_fix_mark_messages_as_read.sql` — corrige l'ambiguïté `conversation_id`
- `supabase/migrations/002_create_chat_media_bucket.sql` — crée bucket `chat-media` + policies RLS storage
- `supabase/migrations/003_wallet_rls_check.sql` — vérifie/corrige RLS wallet (à exécuter si RLS manquantes)

Exécute-les dans l'ordre dans le SQL Editor, puis vérifie :
```sql
select * from storage.buckets; -- doit contenir chat-media
select proname from pg_proc where proname='mark_messages_as_read';
```

Ensuite, pour LiveKit :
- Dashboard > Edge Functions > `create-call-token` > Secrets → ajouter `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` (depuis livekit.cloud)
- Redéployer la function.

Je suis prêt à exécuter dès que tu fournis la service_role key, ou à guider pas-à-pas dans le Dashboard.
