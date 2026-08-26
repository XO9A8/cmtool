# eFootball Club Management & Analytics Tool

[![Rust API](https://img.shields.io/badge/Backend-Rust_Axum-orange?logo=rust)](https://github.com)
[![Flutter](https://img.shields.io/badge/Frontend-Flutter_3.x-blue?logo=flutter)](https://github.com)
[![PostgreSQL](https://img.shields.io/badge/Database-Supabase_PostgreSQL_16-green?logo=postgresql)](https://supabase.com)
[![Docker](https://img.shields.io/badge/Deployment-Docker_/_Railway-blue?logo=docker)](https://railway.app)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

A statically typed, ultra-low-cost competitive eFootball club management and analytics platform engineered with **Rust (Axum API)**, **PostgreSQL (Supabase)**, and **Flutter (Dart)**. 

Designed for low latency ($0–$5/month hosting budget) with on-device OCR extraction, dynamic Elo rating math, Match Performance Score (MPS) analytics, automated tournament scheduling, AI-powered coaching insights, and administrative dispute resolution.

---

## 📘 Documentation Index

Detailed system documentation is located in the [`docs/`](file:///home/nulL/Documents/cmtool/docs) directory:

- 📑 [**Technical Specification**](file:///home/nulL/Documents/cmtool/docs/specification.md): Feature modules, OCR verification flow, complete mathematical specifications, and database DDL.
- 📐 [**System Architecture & Design**](file:///home/nulL/Documents/cmtool/docs/ARCHITECTURE.md): Hexagonal architecture, ports and adapters design, security design, and domain math formulas.
- 🚀 [**Deployment Guide**](file:///home/nulL/Documents/cmtool/docs/DEPLOYMENT.md): Production deployment architecture for Supabase (`ap-southeast-1`), Railway Docker builds, and Flutter build commands.
- 💾 [**Black Falcons Backup Data**](file:///home/nulL/Documents/cmtool/black_falcons_backup.json): Pre-packaged JSON backup and [**SQL Seed**](file:///home/nulL/Documents/cmtool/black_falcons_seed.sql) for rapid environment re-seeding.

---

## 🚀 Key Features & System Modules

### 📱 1. On-Device OCR & Verification Pipeline
- **On-Device Extraction**: Uses Google ML Kit on Flutter to parse eFootball post-match screenshots (Possession, Pass Accuracy, Shots on Target, Interceptions, etc.), completely eliminating cloud image processing costs.
- **Confidence Thresholding**: Triggers interactive manual correction forms when parsed confidence drops below 85%.
- **Match Deduplication & Conflict Detection**: Automatically merges matching submissions from opponent players within a 2-hour window.
- **Dual-Player Confirmation**: Unverified uploads enter a `Pending Verification` queue until approved or auto-confirmed after 24 hours.

### 🏆 2. Mathematical Domain Engine
- **Dynamic Elo Rating Engine (1v1 & 2v2)**: Calculates rating adjustments ($R' = R + K \cdot (S - E)$) with dynamic $K$-factor scaling ($K = K_{base} \cdot M_{margin} \cdot M_{provisional}$).
  - *2v2 Co-op Ratings*: Team Elo $R_{team} = \frac{R_{P1} + R_{P2}}{2}$, distributing rating deltas inversely weighted by baseline skill to prevent rating boosting.
- **Match Performance Score (MPS, 0–100)**: Evaluates match quality independently of match outcome ($MPS = C_{opp} \cdot (w_1 P + w_2 A + w_3 E + w_4 D)$).
- **Form Rating (EWMA)**: Exponentially weighted moving average prioritizing recent performance over past matches.
- **Play Style Classifier**: Evaluates a player's last 20 matches to assign tags (`Possession Master`, `Counter Attacker`, `High Press`, `Out Wide`).

### 🏟️ 3. Tournament & League Operations
- **Automated Seeding & Bracket Generation**: Elo-seeded Knockout bracket generator and Circle Method Round-Robin league scheduler.
- **Official & Admin Dispute Gateway**: Allows players and club officials (`Admin`, `Organizer`, `President`, `Captain`, `Vice-Captain`) to raise result disputes on pending or completed fixtures.
- **Void Match Engine**: Admins can uphold disputes by **voiding matches**, automatically reversing Elo deltas, un-doing League Standings adjustments, and resetting fixtures back to `scheduled` so players can resubmit OCR.

### 🤖 4. AI Coaching Insights & Fallback Engine
- **Google Gemini Integration**: Uses `gemini-2.5-flash` with strict anti-hallucination JSON schema enforcement to output natural language coaching advice.
- **Deterministic Offline Fallback**: Rule-based Rust fallback generator when AI feature flags are disabled or cloud API limits are reached.

---

## 🏗️ Hexagonal System Architecture

The Rust API server follows **Hexagonal Architecture (Ports & Adapters)** to decouple business math from external frameworks and databases:

```text
backend/src/
 ├── api/                   # Primary Adapters (HTTP Transport)
 │    ├── routes.rs         # Axum route handlers & REST HTTP endpoints
 │    ├── auth_middleware.rs# JWT & Bearer token verification
 │    └── jwks.rs           # JWKS key fetching & caching
 ├── domain/                # Core Business Logic (Pure Domain Math)
 │    ├── elo.rs            # Elo rating formulas (1v1 & 2v2)
 │    ├── mps.rs            # Match Performance Score algorithm
 │    ├── play_style.rs     # Play style classifier engine
 │    ├── disputes.rs       # Dispute domain state machine
 │    ├── tournament.rs     # Tournament bracket/league logic
 │    └── ai_insights.rs    # Gemini AI integrations
 └── infrastructure/        # Secondary Adapters (Persistence & External)
      └── postgres_adapter/ # SQLx PostgreSQL database queries
```

---

## ⚡ Quick Start & Development Setup

### 1. Prerequisites
- [Rust](https://www.rust-lang.org/) (Cargo 1.75+)
- [Flutter SDK](https://flutter.dev/) (3.16+)
- [PostgreSQL](https://www.postgresql.org/) (16+) or [Docker](https://www.docker.com/)

### 2. Run Local Backend (Rust API)
```bash
cd backend
cp .env.example .env

# Run using offline SQLx query cache
SQLX_OFFLINE=true cargo run
```
*The backend API server will run on `http://localhost:3000`.*

### 3. Run Flutter Application
```bash
cd mobile

# Run on Desktop (Linux / macOS / Windows)
flutter run --dart-define=SUPABASE_URL="https://ypsrkdefgbghvluuyynm.supabase.co" \
            --dart-define=SUPABASE_ANON_KEY="<YOUR_SUPABASE_ANON_KEY>" \
            --dart-define=BACKEND_URL="http://localhost:3000" \
            -d linux
```

### 4. Running Domain Tests
```bash
cd backend
cargo test
```

---

## 🔌 API Endpoints Summary

| Method | Endpoint | Auth Required | Description |
| :--- | :--- | :---: | :--- |
| `GET` | `/health` | No | Server health check |
| `POST` | `/api/v1/auth/register` | No | Register new user account |
| `POST` | `/api/v1/auth/login` | No | User login & JWT bearer token issue |
| `POST` | `/api/v1/matches/ocr-submit` | Yes | Submit parsed OCR match JSON stats |
| `GET` | `/api/v1/matches/predict` | Yes | Predict match win/draw/loss probabilities |
| `GET` | `/api/v1/leaderboards/{club_id}` | Yes | Fetch real-time club rankings & Elo leaderboard |
| `POST` | `/api/v1/tournaments/bracket` | Yes | Generate Elo-seeded Knockout bracket |
| `POST` | `/api/v1/tournaments/round-robin` | Yes | Generate Circle Method Round-Robin scheduler |
| `GET` | `/api/v1/players/{id}/h2h/{opp}` | Yes | Fetch Head-to-Head rivalry stats |
| `POST` | `/api/v1/disputes` | Yes | Raise match result dispute (Player / Official) |
| `POST` | `/api/v1/admin/disputes/{id}/resolve` | Yes | Resolve dispute (Dismiss or Void Match) |

---

## 🌐 Production Deployment

- **Database**: PostgreSQL 16 hosted on **Supabase** in `ap-southeast-1` (Singapore).
- **API Server**: Deployed on **Railway** (`cmtool-backend-asia`) inside an ultra-lean multi-stage Docker container footprint (< 50MB).
  - **Live URL**: `https://cmtool-backend-asia-production.up.railway.app`
  - **Health Check**: `https://cmtool-backend-asia-production.up.railway.app/health`
  - **Version Check**: `https://cmtool-backend-asia-production.up.railway.app/version`
- **CI/CD & Deployment**: Multi-stage Rust build with `SQLX_OFFLINE=true` compile caching.

### Deploying Backend to Railway
To deploy backend updates using the Railway CLI:
```bash
cd backend
railway up
```

### Syncing Railway Environment Variables
Set and sync environment variables for the Railway production service (`cmtool-backend-asia`):
```bash
cd backend
railway variable set -s cmtool-backend-asia \
  "DATABASE_URL=postgresql://postgres.<project_ref>:<password>@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres" \
  "JWT_SECRET=<SUPABASE_JWT_SECRET>" \
  "SUPABASE_URL=https://ypsrkdefgbghvluuyynm.supabase.co" \
  "SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  "APP_LATEST_VERSION=0.2.1" \
  "APP_LATEST_BUILD=6" \
  "APP_DOWNLOAD_URL=https://drive.google.com/drive/folders/1wRlIh9fDp0S2uN46zcmbIoNWktXl4Un5" \
  "APP_RELEASE_NOTES=Initial release via Google Drive!" \
  "APP_FORCE_UPDATE=false" \
  "ENABLE_AI_INSIGHTS=true" \
  "RUST_LOG=cmtool_backend=info,tower_http=info"
```

### Building Flutter Production APK
Build the release APKs with production environment variables:
```bash
cd mobile
flutter build apk --split-per-abi \
  --dart-define=SUPABASE_URL="https://ypsrkdefgbghvluuyynm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlwc3JrZGVmZ2JnaHZsdXV5eW5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3NjQ4MzEsImV4cCI6MjEwMTM0MDgzMX0.3ojq4TJBGoIM_QwDSzvbJY1VX4LBkpJ3DyDYYcKdLKg" \
  --dart-define=BACKEND_URL="https://cmtool-backend-asia-production.up.railway.app"
```

---

## 📄 License
This project is open source and available under the [MIT License](LICENSE).

