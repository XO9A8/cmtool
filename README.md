# eFootball Club Management & Analytics Tool

A statically typed, ultra-low-cost eFootball competitive management and analytics system built with Rust (Axum API), PostgreSQL (Supabase), and Flutter (Dart).

Designed per the technical specification documented in [docs/specification.md](file:///home/nulL/Documents/cmtool/docs/specification.md).

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

### 1. Run Database Migrations Locally
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

## API Endpoints Reference

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
