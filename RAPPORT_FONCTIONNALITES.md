# Rapport de Fonctionnalités — ChatMe

**App :** ChatMe — Messagerie instantanée Bénin (WhatsApp / WeChat / Instagram)  
**Version code :** `1.0.0+1` (`lib/core/constants/app_constants.dart:5`)  
**Stack :** Flutter + GetX + Supabase (Realtime, Auth, Storage) + Firebase FCM + LiveKit + FedaPay

---

## 1. Vue d'ensemble

ChatMe est un **MVP messagerie complet** articulé en **5 onglets** (`lib/screens/home_screen.dart:1`) :

| Onglet | Écran | Icône | Rôle |
|--------|-------|-------|------|
| 1 | Discussions | `chat_bubble` | Liste conversations + strip Statuts |
| 2 | Moments | `feed` | Feed social type Instagram/WeChat Moments |
| 3 | Portefeuille | `account_balance_wallet` | Wallet FCFA (FedaPay, dépôt/retrait/virement, QR Pay) |
| 4 | Services | `grid_on` | Catalogue services (mini-apps) |
| 5 | Profil | `person` | Profil, QR, paramètres, sécurité |

Flux d'entrée : `SplashScreen` → `RootGate`/`AuthWrapper` → `/phone` ou `/home` selon session Supabase (`lib/screens/splash_screen.dart`, `lib/screens/root_gate.dart`, `lib/widgets/auth_wrapper.dart`).

---

## 2. Matrice des fonctionnalités

Légende : ✅ Opérationnel · 🟡 Partiel / TODO · 🔶 Mock local · ❌ Non implémenté

### 2.1 Authentification (`lib/services/auth_service.dart:550l`, `lib/screens/auth/*`)

| Fonction | Statut | Détails |
|----------|--------|---------|
| **Téléphone + OTP SMS** | ✅ | `sendOtp` / `verifyOtp` via `supabase.auth.signInWithOtp(phone)` (`auth_service.dart:270`). Normalisation Bénin `+229` (`_normalizePhone:525`). Écrans `phone_input_screen.dart`, `otp_verification_screen.dart`. |
| **Email + mot de passe** | ✅ | `signUpWithEmail` / `signInWithEmail` (`auth_service.dart:158-267`). Écran `email_auth_screen.dart`. |
| **Email OTP / Magic Link** | ✅ | `sendEmailOtp`, `verifyEmailOtp` (`auth_service.dart:397-483`), `resendConfirmationEmail`. Deep link `app_links` géré `main.dart:104-123` → `EmailVerificationCallbackScreen`. |
| **Reset password** | ✅ | `resetPassword` (`auth_service.dart:426`). |
| **Profil auto-création** | ✅ | `_ensureProfileExists` avec `upsert` + fallback sans `email` si colonne manquante (`auth_service.dart:101-155`). |
| **Session persistante** | ✅ | `onAuthStateChange` + `_checkCurrentSession` (`auth_service.dart:34-69`), `isInitializing` pour splash. |
| **Déconnexion** | ✅ | `signOut` + `LockService.markLocked` (`auth_service.dart:342`). |
| **Mise à jour profil** | ✅ | `updateProfile` (`auth_service.dart:357`) + `ProfileSetupScreen` / `profile_screen.dart`. |
| **2FA / Vérif en 2 étapes** | 🔶 | Toggle `SettingsService.twoStepVerification` (`settings_service.dart:14`) — UI seulement, pas de logique. |

### 2.2 Discussions & Messagerie (`lib/services/messaging_service.dart:415l`, `lib/screens/discussions_screen.dart`, `lib/screens/chat_screen.dart:774l`)

| Fonction | Statut | Détails |
|----------|--------|---------|
| **Liste conversations** | ✅ | `loadConversations` avec jointure `participants` + `last_message` (`messaging_service.dart:44-84`). Pull-to-refresh, empty state (`discussions_screen.dart:63`). |
| **Realtime conversations** | ✅ | `channel('conversations_changes')` filtré `created_by` (`messaging_service.dart:86`), `channel('messages_changes')` pour inserts/updates (`messaging_service.dart:107`). |
| **Création conversation directe** | ✅ | `createDirectConversation` via RPC `get_or_create_direct_conversation` (`messaging_service.dart:212`). Sheet `showNewSheet` / `chat_sheets.dart`. |
| **Envoi texte** | ✅ | `sendMessage` insert `messages` + update `conversations.updated_at` (`messaging_service.dart:224-269`). |
| **Statuts message** | ✅ | `sent/delivered/read` (`AppConstants:54`), `markAsRead` RPC + update local (`messaging_service.dart:271-294`), double-coche bleue (`chat_screen.dart:535`). |
| **Édition message** | ✅ | `editMessage` + `editLocalMessage` optimiste, `is_edited` flag, fenêtre 15 min (`chat_screen.dart:227`, `messaging_service.dart:333-356`). Long-press → *Modifier*. |
| **Suppression** | ✅ | `deleteMessageForMe` (local) / `deleteMessageForEveryone` (delete SQL) (`messaging_service.dart:358-376`). |
| **Média image/vidéo/fichier** | 🟡 | `uploadMedia` vers bucket `chat-media` + `createSignedUrl` (`messaging_service.dart:307-323`). UI `MessageType.image/video/file` rendue (`chat_screen.dart:568-660`) mais boutons attache/photo = `TODO` (`chat_screen.dart:709-716`). |
| **Messages vocaux** | ✅ | `AudioRecorder` + `AudioPlayer` (`record`, `audioplayers`), `sendVoiceMessage` upload `audio/m4a` (`messaging_service.dart:389-414`), UI enregistrement avec timer (`chat_screen.dart:122-197`). |
| **Pagination** | 🟡 | `loadMessages(limit:50)` + filtre `beforeMessageId` en mémoire (`messaging_service.dart:178-210`), `TODO pagination` au scroll (`chat_screen.dart:84`). |
| **Appels (audio/vidéo)** | 🟡 | Boutons `call` / `videocam` dans `ChatScreen` → `CallScreen` (`chat_screen.dart:353-373`), `CallService` LiveKit (`call_service.dart:215l`) avec `joinCall`, mute/video/speaker, mais **`LIVEKIT_URL` par `dart-define` obligatoire** sinon exception explicite (`call_service.dart:94-100`). Edge Function `create-call-token` requise. |
| **Recherche conversations** | 🔶 | UI `ChatHeader` search + barre `Rechercher` (`discussions_screen.dart:28-50`) mais action = `Get.snackbar('Recherche', …)` mock. |
| **Groupes** | 🟡 | Modèle `Conversation.isGroup` (`conversation.dart`) + UI `showSenderName` en groupe (`chat_screen.dart:468`) mais création groupe non UI. |

### 2.3 Statuts (Stories 24h) (`lib/services/status_service.dart`, `lib/screens/status_post_screen.dart`, `lib/screens/status_viewer_screen.dart`)

| Fonction | Statut | Détails |
|----------|--------|---------|
| **Poster statut** | ✅ | `StatusPostScreen` (texte/photo), `StatusService` + `SharedPreferences` fallback + `removeExpired` (24h) appelé `main.dart:64`. |
| **Viewer** | ✅ | `StatusViewerScreen` avec progression, `viewed` flag. |
| **Strip sur Discussions** | ✅ | `_buildStatusStrip` avec `myActive` / `contactsActive`, anneau coloré (`discussions_screen.dart:88-145`), `_StatusAvatar` avec `+` pour ajouter. |

### 2.4 Moments (Feed social) (`lib/services/moments_service.dart:270l`, `lib/screens/moments_screen.dart`)

| Fonction | Statut | Détails |
|----------|--------|---------|
| **Feed** | ✅ | `MomentsScreen` liste `MomentsService.moments` (RxList), seed 2 moments (`moments_service.dart:99-122`). |
| **Créer moment** | ✅ | `addMoment` texte + `photoPath` (image_picker) (`moments_service.dart:196-233`), Supabase `moments` si disponible sinon local. |
| **Likes** | ✅ | `toggleLike` avec `moment_likes` Supabase si dispo sinon local (`moments_service.dart:152-176`). |
| **Commentaires** | ✅ | `addComment` → `moment_comments` (`moments_service.dart:178-193`). |
| **Suppression / Édition** | ✅ | `deleteMoment`, `updateMoment` (local + `SharedPreferences`). |

### 2.5 Portefeuille / Wallet (`lib/services/wallet_service.dart:648l`, `lib/screens/wallet_screen.dart:420l`)

| Fonction | Statut | Détails |
|----------|--------|---------|
| **Solde & historique** | ✅ | `balance` (cents FCFA) + `transactions` Rx, persistance double `wallet_balances` / `wallet_transactions` Supabase + cache local (`wallet_service.dart:82-178`). Realtime `wallet_balances_$userId`. Empty state “0 FCFA” (`wallet_screen.dart:154-168`). |
| **Recharge FedaPay** | ✅ | `rechargeWithFedapay` conforme docs : `createTransaction` + `getTransactionToken` + `launchUrl` + vérif serveur via Edge Function `verify-fedapay-transaction` (`wallet_service.dart:260-359`). `dart-define FEDA_API_KEY / FEDA_ENV` requis. |
| **Dépôt / Retrait (banque)** | ✅ | `deposit` / `withdraw` via RPC atomiques `wallet_deposit` / `wallet_withdraw` (`wallet_service.dart:474-565`), fallback local si Supabase indispo. Snackbars succès. |
| **Virement P2P** | ✅ | `transferToUser` / `wallet_transfer` RPC (`wallet_service.dart:567-584`), UI `showContactsPaySheet`, `sendMoney` legacy wrapper (`wallet_service.dart:425`). |
| **Paiement QR** | ✅ | `MobileScanner` + `QrFlutter`, formats `chatme://pay?merchant=…&amount=…` ou `name|amount|id` (`wallet_screen.dart:187-341`), confirmation dialog + `payAsync`. |
| **Actions rapides** | ✅ | 3 `QuickAction` Envoyer/Retrait/Payer QR + boutons Dépôt/Recharger (`wallet_screen.dart:51-137`). |

### 2.6 Contacts & QR (`lib/services/contacts_service.dart`, `lib/screens/my_qr_screen.dart`, `lib/screens/scan_contact_screen.dart`)

| Fonction | Statut | Détails |
|----------|--------|---------|
| **QR perso** | ✅ | `MyQrScreen` affiche `qr_flutter` avec payload `chatme:user:<id>:<name>` (`contacts_service.dart:111`). |
| **Scanner contact** | ✅ | `ScanContactScreen` + `MobileScanner`, `parseUserQrPayload` (`contacts_service.dart:115-123`), `addFromScan` avec palette couleurs (`contacts_service.dart:87-107`). |
| **Liste contacts ajoutés** | ✅ | `ContactsService.added` persisté `added_contacts` (`contacts_service.dart:43-72`). |
| **Import répertoire** | ❌ | Stub `importDeviceContacts() → []` (`contacts_service.dart:78-84`), `TODO 2.8` — nécessite `flutter_contacts` + permission `READ_CONTACTS`. |

### 2.7 Profil & Réglages (`lib/screens/profile_screen.dart`, `lib/screens/settings_screen.dart`, `lib/services/settings_service.dart:135l`, `lib/services/lock_service.dart`, `lib/screens/app_lock_screen.dart`)

| Fonction | Statut | Détails |
|----------|--------|---------|
| **Profil** | ✅ | `ProfileScreen` édition `displayName`, `bio`, avatar, `AppConstants` fallbacks. |
| **Settings** | ✅ | `SettingsScreen` 6 sections : Confidentialité (lastSeen, readReceipts, typingIndicator…), Notifications (8 toggles), Discussions/Appels, Portefeuille (paymentPassword, fingerprintPay), Affichage (themeMode `system/light/dark` → `Get.changeThemeMode`), Compte/Région/Langue (`fr/en/fon`). 30+ clés persistées `SharedPreferences` (`settings_service.dart:54-121`). |
| **Thème** | ✅ | Light/Dark Material3 complet (`chatme_theme.dart:104-333`), `SwitchThemeData`, bulles `ChatMeBubbleTheme`. Changement via `SettingsService.themeMode` observé `main.dart:130-142`. |
| **Verrouillage app** | ✅ | `LockService` + `LocalAuth` (biométrie) + `AppLockScreen`, `markLocked` au `signOut` (`auth_service.dart:348`). |
| **Politique sécurité** | ✅ | `SecurityPolicyScreen` statique. |

### 2.8 Services / Catalogue (`lib/core/services/service_catalog.dart`, `lib/screens/services_screen.dart`, `lib/screens/service_detail_screen.dart`)

| Fonction | Statut | Détails |
|----------|--------|---------|
| **Grille services** | ✅ | `ServiceCatalog` liste statique, `ServicesScreen` grid `FeatureTag`, `ServiceDetailScreen`. Contenu mock (guide “Étudier en France”, etc.). |

### 2.9 Notifications Push (`lib/config/firebase_config.dart:111l`, `lib/main.dart`)

| Fonction | Statut | Détails |
|----------|--------|---------|
| **FCM init** | ✅ | `Firebase.initializeApp`, `setForegroundNotificationPresentationOptions`, `requestPermission`, `getToken` + `onTokenRefresh` → `syncTokenToSupabase` (`profiles.fcm_token`) (`firebase_config.dart:22-100`). |
| **Handlers** | ✅ | `onBackgroundMessage`, `onMessage`, `onMessageOpenedApp` loggés (`firebase_config.dart:65-73`). |
| **Deep links** | ✅ | `app_links` URI stream + initialLink (`main.dart:84-102`). |

---

## 3. Parcours utilisateurs clés

1. **Inscription téléphone :** `SplashScreen` → `PhoneInputScreen` → OTP SMS → `ProfileSetupScreen` → `HomeScreen (Discussions)`.
2. **Inscription email :** `EmailAuthScreen` → `EmailVerificationScreen` → clic lien email → `EmailVerificationCallbackScreen` (deep link) → `HomeScreen`.
3. **Chat :** `DiscussionsScreen` → `+` → `showNewSheet` (contact QR / nouveau) → `ChatScreen` → texte/vocal/édition/suppression → appel LiveKit.
4. **Wallet :** `Portefeuille` → Recharger (FedaPay sandbox/live) → Dépôt/Retrait (RPC) → Virement → Scanner QR marchand → Payer.
5. **Moments/Statuts :** `Moments` → créer texte/photo → like/comment ; `Discussions` strip → `StatusPostScreen` → `StatusViewerScreen`.

---

## 4. Couverture fonctionnelle — synthèse

| Domaine | Avancement | Remarque |
|---------|------------|----------|
| Auth (phone/email/OTP) | **90%** | Complet, seul 2FA est mock |
| Messagerie temps réel | **85%** | Realtime OK, média partiel (TODO attach/photo), pagination à finaliser |
| Statuts / Moments | **85%** | Fonctionnel local + Supabase si tables déployées |
| Wallet / FedaPay | **80%** | Recharge + banque RPC complets, webhook à déployer côté Supabase |
| Contacts QR | **75%** | QR add OK, import répertoire à faire |
| Appels LiveKit | **60%** | Client prêt, infra (LIVEKIT_URL + Edge Function) à configurer |
| Settings / Thème / Lock | **95%** | Très complet (30 toggles) |
| Services catalogue | **70%** | UI mock, pas de mini-apps réelles |
| Notifications FCM | **75%** | Token sync OK, routing notif → conversation à enrichir |
| **Global MVP** | **~80%** | **Prêt pour bêta fermée** une fois `flutter create` + Supabase RLS + FedaPay/LiveKit configurés |

---

## 5. Ce qui reste à faire (fonctionnel)

**P0 :**
- Câbler `TODO` pièce jointe / photo dans `ChatScreen` ( `image_picker` déjà dépendance).
- Implémenter pagination `loadMessages(beforeMessageId)` côté SQL (`lt`).
- Déployer SQL `supabase_wallet_bank.sql` + `fix_wallet_rls.sql` + Edge Functions `verify-fedapay-transaction` / `create-call-token`.

**P1 :**
- Import contacts `flutter_contacts` si besoin produit WhatsApp.
- Recherche conversations (filtrer `conversations` par `getTitle`).
- Groupes (création, ajout membres, avatar groupe).

**P2 :**
- Chiffrement E2E (actuellement clair dans `messages`).
- Stories Moments en plein écran vidéo, réactions emoji (`cReactions` déjà palette).

---

*Rapports générés : `AUDIT.md` (technique) + `RAPPORT_FONCTIONNALITES.md` (celui-ci) + fichiers Flutter reconstitués à la racine.*
