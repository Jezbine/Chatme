# Audit Technique — ChatMe (Flutter)

**Date:** 2026-09-10  
**Périmètre:** `C:/Users/Ebenezer/OneDrive/Desktop/chatME` — seul `lib/` présent à l'arrivée, 56 fichiers Dart, ~11 685 lignes  
**Action réalisée:** Reconstitution des fichiers manquants type `flutter create` (`pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `.metadata`, `l10n.yaml`, `web/`, `test/`, `android/ios/...` stubs, `.env.example`, `README.md`)

---

## 1. Reconstitution — ce qui a été fait

| Fichier | Statut | Détails |
|---------|--------|---------|
| `pubspec.yaml` | **Créé** | `name: chatme` déduit des imports `package:chatme/...`. 19 dépendances inférées par scan des `import` (`get`, `supabase_flutter`, `firebase_core`, `firebase_messaging`, `app_links`, `livekit_client`, `feda_flutter`, `audioplayers`, `record`, `image_picker`, `qr_flutter`, `mobile_scanner`, `shared_preferences`, `local_auth`, `permission_handler`, `path_provider`, `url_launcher`, `crypto`, `intl`). `sdk >=3.2.0`, `flutter >=3.22.0`. |
| `analysis_options.yaml` | **Créé** | `flutter_lints` + règles custom, `avoid_print: false` (logs debug autorisés) |
| `.gitignore` | **Créé** | Standard Flutter + exclusion `.env`, `firebase_options.dart`, `*.map.json` |
| `.metadata` | **Créé** | `project_type: app`, channel stable |
| `l10n.yaml` | **Créé** | Préparé pour i18n FR |
| `README.md` | **Créé** | Procédure `flutter create .`, variables `--dart-define` |
| `.env.example` | **Créé** | Template Supabase / FedaPay / LiveKit |
| `test/widget_test.dart` | **Créé** | Smoke test minimal |
| `web/index.html` + `manifest.json` | **Créé** | Minimal PWA |
| `android/ ios/ windows/ linux/ macos/ assets/` | **Stubs `.gitkeep`** | **À régénérer** : `flutter create . --platforms=android,ios,web,windows,linux,macos` reste nécessaire pour générer Gradle/Xcode/CMake complets. Sans SDK Flutter local, génération native complète impossible. |

> **Prochaine étape obligatoire** après installation Flutter :
> ```bash
> flutter create . --platforms=android,ios,web,windows,linux,macos
> flutter pub get
> flutter analyze
> flutter test
> ```

---

## 2. Architecture

**Pattern:** GetX monolithique (DI + navigation + state). Pas de Clean Architecture / Riverpod / Bloc — choix pragmatique pour MVP.

```
lib/
  main.dart                # bootstrap parallèle (Supabase+Firebase), DI Get.put x8, deep links app_links
  config/                  # SupabaseConfig, FirebaseConfig (FCM token sync)
  core/
    theme/chatme_theme.dart  # Light/Dark Material3, ChatMeBubbleTheme extension, spec §2-§4
    constants/               # AppConstants + mock_data
    errors/failure.dart      # Failure hierarchy (Server/Auth/Validation...)
    exceptions/app_exceptions.dart # mapAuthError FR
    utils/                   # validators, date/string extensions, ui_utils (showError)
    services/service_catalog.dart # catalogue Services (grid)
  models/                  # user_profile, conversation (participants, lastMessage), message (type/status), moment
  services/ (GetxService)  # auth, messaging, wallet, moments, contacts, settings, status, lock, call
  screens/                 # splash, home (5 tabs), discussions, chat, moments, wallet, services, profile, settings...
  widgets/                 # auth_wrapper, chat_header, chat_sheets, feature_tag
```

**Points forts:**
- Bootstrap optimisé `lib/main.dart:32-66` : `Future.wait` parallèle + `addPostFrameCallback` pour tâches non critiques → évite “Choreographer skipped frames”.
- Deep links centralisés `lib/main.dart:84-123` (callback email, `app_links`).
- Realtime Supabase (`messaging_service.dart:86-129`, `wallet_service.dart:180-212`, `moments_service.dart:77-88`) bien câblé.
- Thème robuste `lib/core/theme/chatme_theme.dart:104-333` : `ColorScheme.fromSeed`, `ThemeExtension` bulles, gestion clair/sombre conforme spec.

**Points faibles:**
- Couplage fort à `Get.find()` partout (testabilité faible, pas d'abstraction repository).
- `SupabaseConfig.client` static → impossible de mocker ; `services/*` accèdent directement à Supabase sans couche d'abstraction.
- `lib/models/` sans `json_serializable` / `freezed` : parsing manuel verbeux et fragile.
- Absence de dossiers `assets/`, `l10n/`, `test/` fournis avant reconstitution.

---

## 3. Qualité de code

| Critère | Note | Observations |
|---------|------|--------------|
| **Taille** | 56 fichiers / 11 685 lignes | Cohérent MVP ; `chat_screen.dart:774l`, `wallet_service.dart:648l`, `chat_sheets.dart:23887B` volumineux → à découper |
| **Lint** | `analysis_options.yaml` créé | `flutter analyze` non exécuté (SDK absent) ; `avoid_print: false` masque 40+ `print` debug |
| **Duplication** | Moyenne | `_normalizePhone` dupliqué, formatage FCFA `replaceAllMapped(RegExp…)` répété 3× (`wallet_service.dart:609`, `wallet_screen.dart:343`) |
| **TODO / FIXME** | 4 occurrences | `chat_screen.dart:84` pagination, `chat_screen.dart:709` pièce jointe, `chat_screen.dart:715` photo, `contacts_service.dart:80` import répertoire |
| **Gestion d'erreurs** | Hétérogène | `AppExceptions.mapAuthError` bien localisé FR (`lib/core/exceptions/app_exceptions.dart:96`), mais fallback `errorMessage.value = e.toString()` brut dans plusieurs services |
| **Null-safety** | OK | Dart 3.2+ ; quelques `!` dangereux (`chat_screen.dart:314` `getAvatarUrl(currentUserId)`) |
| **Tests** | 0% → smoke créé | Aucun test avant ; `test/widget_test.dart` ajouté mais ne couvre rien |

---

## 4. Sécurité — **CRITIQUE**

| # | Sévérité | Fichier | Problème | Reco |
|---|----------|---------|----------|------|
| **S1** | 🔴 Haute | `lib/config/supabase_config.dart:4` + `lib/core/constants/app_constants.dart:9` | **Clé Supabase publishable hardcodée** dans le code (`sb_publishable_mG2qOXX7Dzi4ZCxfDNZs3w_VUuqYiJt`) + URL en clair. Repo = fuite. | Passer par `--dart-define=SUPABASE_URL --dart-define=SUPABASE_ANON_KEY` + `String.fromEnvironment`, ou `flutter_dotenv` + `.env` ignoré. Rotater la clé dans Supabase Dashboard. |
| **S2** | 🔴 Haute | `lib/core/constants/app_constants.dart:12` | `supabaseServiceRoleKey` prévu en `static String?` → risque d'embarquer la **service_role** côté client (bypass RLS). | **Jamais** côté client ; réserver aux Edge Functions / backend. Supprimer le champ. |
| **S3** | 🟠 Moyenne | `lib/services/wallet_service.dart:62`, `lib/services/call_service.dart:95` | `String.fromEnvironment` sans validation forte ; fallback `pk_sandbox_placeholder` → recharge silencieusement inactive. | Lever exception explicite si clé manquante en `--dart-define` pour `live`, logger warning sandbox. |
| **S4** | 🟠 Moyenne | `lib/config/supabase_config.dart` | `fcm_token` sync sans vérif RLS. Si politiques RLS incomplètes, écriture `profiles` possible par tiers. | Documenter `fix_wallet_rls.sql` / `supabase_wallet_bank.sql` ; vérifier que RLS `profiles` n'autorise `update` que sur `auth.uid() = id`. |
| **S5** | 🟡 Faible | `lib/config/firebase_config.dart` | `Firebase.initializeApp()` sans `firebase_options.dart` (qui doit être généré et ignoré). | Générer via `flutterfire configure`, ajouter à `.gitignore` (déjà fait). |
| **S6** | 🟡 Faible | `lib/core/constants/mock_data.dart` | Données mock potentiellement exposées en prod si fallback local utilisé. | Conditionner `mock_data` à `kDebugMode`. |

---

## 5. Performance & Fiabilité

- **Main thread** : Correct (parallélisation) mais 8 `Get.put` synchrones + 6 `init()` en `Future.wait` peuvent échouer en cascade sans `try/catch` global (`lib/main.dart:53-60`).
- **Realtime** : Channels non limités (`messages_changes` écoute **tous** les inserts `messages` sans filtre `conversation_id` → bruit réseau sur gros volume) — `lib/services/messaging_service.dart:111`.
- **Chat pagination** : `loadMessages` charge 50 derniers (`order desc`) puis filtre en mémoire (`lib/services/messaging_service.dart:194-202`) → inefficace. `TODO pagination` non implémenté (`chat_screen.dart:84`).
- **Wallet** : Double persistance (`SharedPreferences` + Supabase) avec `_persistLocal()` systématique → OK offline mais risque de divergence si `balance` updaté localement puis RLS refuse `upsert`.
- **Audio** : `AudioRecorder` + `AudioPlayer` sans `Permission.microphone` explicite avant `record` (vérif `hasPermission` à `lib/screens/chat_screen.dart:125` mais pas de `permission_handler` request).
- **Images** : `Image.network` sans `cache` (`chat_screen.dart:575`) → re-téléchargement à chaque scroll.

---

## 6. Conformité Flutter / Pub

- **Pubspec créé** avec versions récentes (supabase_flutter `^2.8.1`, firebase_messaging `^15.2.4`, livekit_client `^2.4.8`). À vérifier `flutter pub get` une fois SDK installé (conflits `intl` / `firebase_core` fréquents).
- **Assets** : `pubspec.yaml` référence `assets/` vide → OK mais `fontFamily: 'Inter'` déclaré dans `chatme_theme.dart` sans fichier font → fallback système silencieux.
- **Platforms** : Stubs uniquement ; `flutter create .` obligatoire pour obtenir `android/app/build.gradle`, `ios/Runner.xcodeproj`, `windows/CMakeLists.txt`, etc. Sans cela `flutter build` échouera.
- **L10n** : Aucun `arb` ; langue codée en `settings_service.dart:45` (`fr` par défaut) mais `intl` déjà dépendance → prévoir `flutter gen-l10n`.

---

## 7. Dette & Risques

1. **Bus GetX global** : `Get.find<AuthService>()` dans `MessagingService` (`lib/services/auth_service.dart:44`) → dépendance circulaire implicite.
2. **Suppression message** : `deleteMessageForEveryone` supprime côté client sans vérifier `sender_id == auth.uid()` (`lib/services/messaging_service.dart:371`) → faille si RLS non stricte.
3. **Wallet placeholder** : Si `FEDA_API_KEY` placeholder, `rechargeWithFedapay` ouvre quand même UI puis échoue → UX confuse.
4. **CallService** : `LIVEKIT_URL` lève exception (`lib/services/call_service.dart:98`) mais `joinCall` `rethrow` sans UI → crash non catch côté `CallScreen`.
5. **Settings** : 30+ clés `SharedPreferences` sans migration de schéma ; renommage = perte réglages.

---

## 8. Recommandations priorisées

**P0 — Avant release :**
- [ ] Externaliser `Supabase URL/Key` en `dart-define` + rotater clé exposée.
- [ ] Supprimer `supabaseServiceRoleKey` du client.
- [ ] `flutterfire configure` + vérifier RLS `profiles`, `wallet_balances`, `wallet_transactions`, `messages`.
- [ ] `flutter create . --platforms=...` + `flutter pub get` + `flutter analyze` → corriger warnings.

**P1 — Court terme :**
- [ ] Filtrer Realtime `messages` par `conversation_id` (ou par participant).
- [ ] Implémenter pagination `loadMessages` côté SQL (`lt created_at` + `order` + `limit`).
- [ ] Extraire `WalletService` / `MessagingService` derrière interfaces Repository pour testabilité.
- [ ] Ajouter `permission_handler` request microphone / caméra avant `record`.
- [ ] Ajouter tests unitaires `wallet_service`, `auth_service.normalizePhone`, `parseUserQrPayload`.

**P2 — Moyen terme :**
- [ ] Migrer `models` vers `freezed` + `json_serializable`.
- [ ] Découper `chat_screen.dart` (774l) en `chat_input_bar.dart`, `message_bubble.dart`, `voice_recorder.dart`.
- [ ] Cacher `assets/fonts/Inter` ou retirer `fontFamily`.
- [ ] Ajouter `flutter_gen` pour assets, `very_good_analysis` pour lint strict.

---

*Fichiers reconstitués vérifiables : `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `.metadata`, `l10n.yaml`, `web/`, `test/`, `.env.example`, `README.md` — tous présents à la racine.*
