# Project Deployment Guide

This document explains the current production deployment strategy for the eFootball Club Management & Analytics Tool, detailing how the database and backend are hosted.

## 1. Hosting Architecture

The backend infrastructure is split into two specialized services optimized for low latency and high performance:

1.  **Supabase (PostgreSQL 16)**: Hosts the relational database, handles Row-Level Security (RLS), and manages user authentication (identities, sessions, OAuth).
2.  **Railway (Docker Container)**: Hosts the Rust Axum API backend. It connects to the Supabase database via connection pooling.

**Region Targeting:**
Both the Railway backend and the Supabase database are currently deployed in the **Asia (Singapore - `ap-southeast-1` / `southeast-asia`)** region. Co-locating the API and Database in the same region ensures ultra-low latency for internal database queries.

## 2. Supabase Setup (`cmtool-asia`)

The Supabase project is the central source of truth.

**Current Production Details:**
*   **API URL:** `https://ypsrkdefgbghvluuyynm.supabase.co`
*   **Anon Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlwc3JrZGVmZ2JnaHZsdXV5eW5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NjQ4MzEsImV4cCI6MjEwMTM0MDgzMX0.3ojq4TJBGoIM_QwDSzvbJY1VX4LBkpJ3DyDYYcKdLKg`

**Database Schema & Migrations:**
The database schema was generated from the SQL files located in `migrations/`. When the Rust backend starts, it runs `sqlx::migrate!("migrations")` to automatically apply any pending schema changes, ensuring the production database structure is always in sync with the application code.

## 3. Railway Setup (`cmtool-backend-asia`)

The Rust backend is deployed on Railway using a multi-stage `Dockerfile`.

1.  **Build Stage:** Uses `rust:slim-bookworm` to compile the application. We use offline `sqlx` caching (`SQLX_OFFLINE=true`) utilizing the `.sqlx` directory to build the binary without requiring a live database connection during CI/CD.
2.  **Runtime Stage:** Uses a minimal `debian:bookworm-slim` image, creating an ultra-lean final image footprint (< 50MB) containing only the compiled binary and essential CA certificates.

**Environment Variables in Railway:**
*   `DATABASE_URL`: Points to the Supabase Postgres connection pooler (e.g., `postgresql://postgres...`).
*   `JWT_SECRET`: Copied from the Supabase API Settings. Used by the Rust backend to cryptographically verify incoming JWT Bearer tokens from the mobile app.
*   `SUPABASE_URL`: Supabase project API URL.
*   `SUPABASE_ANON_KEY`: Supabase anon/public key.
*   `APP_LATEST_VERSION`: Latest version string (e.g. `0.2.1`).
*   `APP_LATEST_BUILD`: Integer build number (e.g. `6`).
*   `APP_DOWNLOAD_URL`: URL to download updated APK.
*   `APP_RELEASE_NOTES`: Release changelog text.
*   `APP_FORCE_UPDATE`: Boolean (`true` or `false`) to enforce hard updates.
*   `GEMINI_API_KEY`: *(Optional)* Google Gemini API Key for coaching insights.
*   `RUST_LOG`: `cmtool_backend=info,tower_http=info`.

**Deploying Updates to Railway:**
```bash
cd backend
railway up
```

**Syncing Environment Variables via CLI:**
```bash
cd backend
railway variable set -s cmtool-backend-asia \
  "APP_LATEST_VERSION=0.2.1" \
  "APP_LATEST_BUILD=6" \
  "APP_DOWNLOAD_URL=https://drive.google.com/drive/folders/1wRlIh9fDp0S2uN46zcmbIoNWktXl4Un5" \
  "APP_RELEASE_NOTES=Initial release via Google Drive!" \
  "APP_FORCE_UPDATE=false" \
  "ENABLE_AI_INSIGHTS=true" \
  "RUST_LOG=cmtool_backend=info,tower_http=info"
```

## 4. Mobile App Integration

The Flutter mobile application connects directly to the Supabase instance for Authentication (Login/Register) using the Supabase Flutter SDK. 
All other business logic requests (brackets, AI insights, Elo calculation) are routed through the custom Rust API.

To run the Flutter app connected to the live Asian production environment, use:

```bash
cd mobile
flutter run --dart-define=SUPABASE_URL="https://ypsrkdefgbghvluuyynm.supabase.co" --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlwc3JrZGVmZ2JnaHZsdXV5eW5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NjQ4MzEsImV4cCI6MjEwMTM0MDgzMX0.3ojq4TJBGoIM_QwDSzvbJY1VX4LBkpJ3DyDYYcKdLKg" --dart-define=BACKEND_URL="https://cmtool-backend-asia-production.up.railway.app"
```

Build APK:

```bash
cd mobile
flutter build apk --split-per-abi --dart-define=SUPABASE_URL="https://ypsrkdefgbghvluuyynm.supabase.co" --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlwc3JrZGVmZ2JnaHZsdXV5eW5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NjQ4MzEsImV4cCI6MjEwMTM0MDgzMX0.3ojq4TJBGoIM_QwDSzvbJY1VX4LBkpJ3DyDYYcKdLKg" --dart-define=BACKEND_URL="https://cmtool-backend-asia-production.up.railway.app"
```

//release complete
```bash
flutter build apk --dart-define=SUPABASE_URL="https://ypsrkdefgbghvluuyynm.supabase.co" --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." --dart-define=BACKEND_URL="https://cmtool-backend-asia-production.up.railway.app"
```