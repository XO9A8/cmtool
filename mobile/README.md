# eFootball Mobile Management App (Frontend)

This is the Flutter client for the eFootball Club Management & Analytics Tool. It handles real-time match stats upload, OCR verification, leaderboard viewing, and tournament progression.

## Tech Stack
- **Framework:** Flutter (Dart) (>= 3.2.0)
- **State Management:** Riverpod (`flutter_riverpod`)
- **Networking:** Dio (`dio`)
- **Authentication/Real-time:** Supabase (`supabase_flutter`)
- **Local Storage:** SQLite (`sqflite`)
- **OCR Engine:** Google ML Kit (`google_mlkit_text_recognition`)

## Domain-Driven Design (Clean Architecture)

The codebase is strictly structured following DDD and Clean Architecture principles to separate business logic from the UI and external integrations:

```text
lib/
 ├── data/           # Data Transfer Objects (DTOs), hardcoded assets, and raw data sources (e.g. guide_content.dart)
 ├── domain/         # Core business logic models (e.g. match_record.dart) and pure domain services (e.g. ocr_parser_service.dart)
 ├── infrastructure/ # External APIs (api_client.dart), local database (offline_sync_service.dart), and update handlers
 └── presentation/   # UI Layer (Screens, Widgets, Riverpod Providers, App Theme)
```

## Running the App

The mobile app relies on the Rust backend and the Supabase database. Ensure the backend is running locally before launching the app.

```bash
flutter run --dart-define=SUPABASE_URL="https://your_supabase_url.supabase.co" \
            --dart-define=SUPABASE_ANON_KEY="<YOUR_SUPABASE_ANON_KEY>" \
            --dart-define=BACKEND_URL="http://localhost:3000" \
            -d linux
```

For more detailed deployment instructions and architecture overview, please refer to the documentation in the root `docs/` directory.
