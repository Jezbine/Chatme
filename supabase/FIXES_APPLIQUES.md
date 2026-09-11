# Fixes appliqués — 2026-09-10

## 1. Scan contact → validation mutuelle
**Problème:** Scan ajoutait directement le contact sans accord de l'autre personne.
**Fix:**
- Nouvelle table `contact_requests` (migration 004) avec RLS + realtime
- `lib/services/contacts_service.dart:1` — ajout `ContactRequest` model, `sendContactRequest()`, `acceptRequest()`, `rejectRequest()`, `incomingRequests/outgoingRequests` (Rx), subscription realtime
- `lib/screens/scan_contact_screen.dart:18` — scan envoie maintenant une **demande** (`sendContactRequest`) → snackbar "Demande envoyée, l'autre doit valider". Si table non déployée, fallback local.
- Nouveau `lib/screens/contact_requests_screen.dart` — liste des demandes reçues/envoyées avec boutons Accepter/Refuser

**À faire côté BD (SQL Editor):**
```sql
-- Copiez-collez supabase/migrations/004_contact_requests.sql
```
Puis tester: A scanne B → B voit badge/demande dans ContactRequestsScreen → Accepter → A apparaît dans contacts des deux.

## 2. Envoi message → erreur
**Problème:** `Erreur envoi: ...` à chaque message.
**Causes trouvées en direct DB:**
- `mark_messages_as_read` bug `42702 column reference "conversation_id" is ambiguous`
- Bucket `chat-media` inexistant (`storage.buckets = []`)
- RLS `messages`/`wallet` manquantes possibles
**Fix code:**
- `lib/services/messaging_service.dart:306` — `markAsRead` tente `p_conversation_id/p_message_id` puis fallback
- `lib/services/messaging_service.dart:259` — `sendMessage` messages d'erreur amicaux (RLS, Bucket, permission) + `errorMessage` branché à `main.dart:80` `_wireErrorPopups` → snackbar visible
- `lib/services/messaging_service.dart:342` — `uploadMedia` message spécifique si bucket manquant
**Fix BD (SQL Editor):**
```sql
-- 001_fix_mark_messages_as_read.sql
-- 002_create_chat_media_bucket.sql
-- 003_wallet_rls_check.sql
```
Ordre: 001, 002, 003.

## 3. Nouveau compte → redirection/code non reçu
**Problème:** Email de confirmation n'arrive pas, redirection Supabase échoue, code SMS non envoyé.
**Causes trouvées:**
- `POST /auth/v1/signup` → `429 over_email_send_rate_limit` (limite Supabase atteinte, SMTP par défaut non configuré)
- `emailRedirectTo` non défini → Supabase redirige vers Site URL web au lieu de l'app
- `SMS provider` (Twilio) non configuré → `sendOtp` échoue silencieusement
- Deep link `main.dart:104` ne gérait que `?token=` en query, pas le fragment `access_token` ni `io.supabase.chatme://`
**Fix code:**
- `lib/services/auth_service.dart:158` — `signUpWithEmail` ajoute `emailRedirectTo: io.supabase.chatme://login-callback/` (surcharge via `--dart-define=SUPABASE_REDIRECT_URL=...`)
- `lib/services/auth_service.dart:396` — `sendEmailOtp` idem + gestion 429 "Limite atteinte, configurez SMTP"
- `lib/services/auth_service.dart:270` — `sendOtp` message explicite si SMS provider manquant
- `lib/services/auth_service.dart:426` — `resetPassword` avec `redirectTo`
- `lib/main.dart:104` — `_handleDeepLink` gère maintenant `access_token` en fragment, `code`, `token_hash`, `io.supabase.chatme://login-callback`
**Fix Dashboard Supabase (à faire manuellement):**
1. Dashboard > Authentication > URL Configuration
   - Site URL: `io.supabase.chatme://login-callback/` (ou `https://zunviylosliunknpneph.supabase.co`)
   - Redirect URLs (ajouter toutes): `io.supabase.chatme://login-callback/`, `chatme://auth/callback`, `https://zunviylosliunknpneph.supabase.co/auth/v1/callback`
2. Authentication > Email Templates → vérifier "Confirm signup" activé
3. Authentication > SMTP → configurer SMTP custom (ex: Resend, SendGrid) pour éviter rate limit 429 (sinon mails Supabase limités à ~2/h)
4. Authentication > SMS Provider → configurer Twilio (ou désactiver téléphone et n'utiliser que Email)
5. Authentication > Rate Limits → augmenter si besoin

**Test:** Crée un compte avec `+229...` (si SMS configuré) ou email gmail → vérifie réception mail (vérifier spams) → clic lien → app s'ouvre via deep link → HomeScreen.

## 4. Travail direct BD — état actuel
Avec clé anon `sb_publishable_*`, lecture OK mais DDL impossible. Tables existantes vides, 2 bugs confirmés (mark_messages_as_read, bucket). Pour que je patch directement sans passer par SQL Editor, fournis la **service_role key** (Project Settings > API Keys > service_role `sb_secret_...`). Je ne la stocke pas, usage ponctuel.

Sinon, exécute les 4 fichiers `supabase/migrations/*.sql` dans SQL Editor, puis dans Edge Functions > `create-call-token` > Secrets → ajouter `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` et redeploy (fix 503 BOOT_ERROR constaté).

Tous les fichiers SQL sont prêts à copier-coller. Code app déjà corrigé, prêt à `flutter run --dart-define=SUPABASE_REDIRECT_URL=io.supabase.chatme://login-callback/`.
