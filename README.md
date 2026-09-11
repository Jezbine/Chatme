# ChatMe

Messagerie instantanée à la WhatsApp pour le Bénin — Flutter + Supabase + Firebase FCM + LiveKit + FedaPay.

## Stack
- **Flutter** >=3.22 / Dart >=3.2
- **GetX** (DI, state, navigation)
- **Supabase** (auth, realtime, storage)
- **Firebase Messaging** (push FCM)
- **LiveKit** (appels audio/vidéo)
- **FedaPay** (wallet / Mobile Money)

## Démarrage

```bash
# 1. Installer Flutter (si manquant)
# https://docs.flutter.dev/get-started/install

# 2. Régénérer les plateformes natives (ce dossier n'avait que lib/)
flutter create . --platforms=android,ios,web,windows,linux,macos

# 3. Installer les dépendances
flutter pub get

# 4. Configurer Supabase / Firebase
# - Copier .env.example -> .env.local et remplir les clés
# - Placer google-services.json (Android) et GoogleService-Info.plist (iOS)
# - firebase_options.dart sera généré via `flutterfire configure`

# 5. Lancer en sandbox FedaPay + LiveKit
flutter run --dart-define=FEDA_API_KEY=pk_sandbox_xxx --dart-define=FEDA_ENV=sandbox --dart-define=LIVEKIT_URL=wss://xxx.livekit.cloud
```

## Variables d'environnement (dart-define)

| Clé | Description |
|-----|-------------|
| `FEDA_API_KEY` | Clé FedaPay (pk_sandbox_ / pk_live_) |
| `FEDA_ENV` | `sandbox` ou `live` |
| `LIVEKIT_URL` | URL serveur LiveKit (wss://...) |

Supabase et Firebase sont actuellement hardcodés dans `lib/config/` (voir Audit).

## Structure
```
lib/
  config/        # Supabase / Firebase init
  core/          # theme, constants, errors, utils
  models/        # user_profile, conversation, message, moment
  services/      # GetxService : auth, messaging, wallet, call, etc.
  screens/       # splash, home, discussions, chat, wallet, moments...
  widgets/       # feature_tag, chat_sheets, auth_wrapper
```

## Build
```bash
flutter build apk --release
flutter build ios --release
flutter build web --release
```
