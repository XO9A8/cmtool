# eFootball Club Management & Analytics Tool

A statically typed, ultra-low-cost eFootball competitive management and analytics platform engineered with Rust (Axum API), PostgreSQL (Supabase), and Flutter (Dart).

Designed per the technical specification in [docs/specification.md](file:///home/nulL/Documents/cmtool/docs/specification.md) and system architecture in [docs/ARCHITECTURE.md](file:///home/nulL/Documents/cmtool/docs/ARCHITECTURE.md).

---

## Technical Documentation Index

- 📘 [Technical Specification](file:///home/nulL/Documents/cmtool/docs/specification.md): Feature scope, DB schema DDL, REST API endpoints, and evolutionary architecture roadmap.
- 📐 [System Architecture & Design](file:///home/nulL/Documents/cmtool/docs/ARCHITECTURE.md): Hexagonal architecture diagram, Elo & MPS mathematical formulas, database ERD, and security design.
- 📋 [Walkthrough Report](file:///home/nulL/.gemini/antigravity-ide/brain/14772e8e-4b98-43e0-b0c4-75235b7a805a/walkthrough.md): Complete full-stack verification status & unit test results.

---

## Key Features

- 🏆 **Dynamic Elo Rating Engine (1v1 & 2v2)**: Dynamic $K$-factor scaling ($K_{base} \cdot M_{margin} \cdot M_{provisional}$) and inverse-weighted 2v2 co-op ratings.
- 📊 **Match Performance Score (MPS, 0–100)**: Evaluates possession, pass accuracy, shot conversion efficiency, and interceptions with opponent coefficient $C_{opp}$.
- 🤖 **Google Gemini AI & Fallback Insights**: Integrates `gemini-2.5-flash` with JSON mode schema enforcement and anti-hallucination prompting, backed by a deterministic offline fallback.
- 🎯 **Automated Tournament Brackets & Fixtures**: Elo-seeded Knockout bracket generator and Circle Method Round-Robin league scheduler.
- 🔮 **Match Prediction Engine**: Calculates live Win / Draw / Loss probabilities based on expected Elo score ($E$) and H2H records.
- 🔒 **Argon2id & JWT Authentication**: Argon2id password hashing and 24-hour signed JWT bearer token security.
- 🏷️ **Play Style Classifier & Badges**: Categorizes players (`Possession Master`, `Counter Attacker`, `High Press`, `Out Wide`) and awards milestone badges.
- 📜 **Seasons Archive & Dispute Queue**: Archived season snapshots and match dispute resolution lifecycle.

---

## Quick Start (1-Command Docker Deployment)

Run the entire full-stack system (PostgreSQL 16 DB with auto-applied migrations + Rust API Server) in one command:

```bash
docker-compose up --build -d
```
*(Or use `podman-compose up --build -d` on Fedora)*

- **API Server**: `http://localhost:3000`
- **PostgreSQL Database**: `localhost:5432`

---

## Development Setup

### 1. Database Setup
```bash
psql -U postgres -d postgres -f migrations/20260731000000_initial_schema.sql
```

### 2. Run Rust Backend API Server
```bash
cd backend
cp .env.example .env
cargo run
```

To run domain math unit tests:
```bash
cargo test
```

### 3. Run Flutter Mobile App (Linux Desktop / Mobile)
```bash
cd mobile
flutter run -d linux
```

---

## REST API Endpoints Reference

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/api/v1/auth/register` | User registration & Argon2id + JWT token generation |
| `POST` | `/api/v1/auth/login` | User login & JWT token generation |
| `GET` | `/health` | Server health status check |
| `POST` | `/api/v1/matches/ocr-submit` | Submit OCR match stats JSON + SHA-256 screenshot hash |
| `GET` | `/api/v1/matches/predict` | Predict match outcome probabilities |
| `GET` | `/api/v1/leaderboards/{club_id}` | Retrieve real-time club rankings |
| `POST` | `/api/v1/tournaments/bracket` | Generate Elo-seeded Knockout bracket |
| `POST` | `/api/v1/tournaments/round-robin` | Generate Circle Method Round-Robin fixtures |
| `GET` | `/api/v1/players/{id}/h2h/{opp}` | Head-to-Head rivalry stats |
| `POST` | `/api/v1/disputes` | Raise match result dispute |
| `POST` | `/api/v1/seasons/snapshot` | Archive season player snapshot |
