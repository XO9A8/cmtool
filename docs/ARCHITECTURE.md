# System Architecture & Design

This document provides a high-level overview of the eFootball Club Management & Analytics Tool's system architecture, including the backend structure, domain mathematics, database ERD, and security design.

## 1. High-Level System Architecture

The project is built on a modern, typed, low-cost stack:

*   **Mobile Client (Frontend):** Flutter (Dart) app built for iOS, Android, and Desktop. It uses Riverpod for state management, Dio for REST API calls, and the Supabase Flutter SDK for real-time authentication and database synchronization.
*   **API Server (Backend):** Rust (Axum framework) server providing a high-performance RESTful JSON API.
*   **Database (Persistence):** PostgreSQL hosted on Supabase. It uses Supabase Auth for identity management, row-level security (RLS), and acts as the central source of truth.
*   **Hosting / Deployment:** The Rust backend is packaged in a lean Docker container (under 50MB) and deployed to Railway.

## 2. Frontend Architecture (Mobile)

The Flutter mobile application uses a Domain-Driven Design (DDD) / Clean Architecture layout to separate business logic from the UI:

```text
mobile/lib/
 ├── data/           # Data Transfer Objects (DTOs), hardcoded assets, and raw data sources
 ├── domain/         # Core business logic models and pure domain services (e.g. OCR parser)
 ├── infrastructure/ # External APIs (ApiClient), local database (sqflite), and sync services
 └── presentation/   # UI Layer (Screens, Widgets, Riverpod Providers, App Theme)
```

- **Presentation Layer:** Uses `flutter_riverpod` for declarative state management.
- **Infrastructure Layer:** Implements API calls via `dio` and offline caching via `sqflite`.

## 3. Hexagonal Architecture (Backend)

The Rust backend is structured using principles of Hexagonal Architecture (Ports and Adapters) to isolate business logic from external concerns:

```text
src/
 ├── api/           # Primary Adapters (HTTP Transport)
 │    ├── routes.rs # Axum route handlers & REST endpoints
 │    ├── auth_middleware.rs # JWT verification
 │    └── jwks.rs   # JWKS fetching
 ├── domain/        # Core Business Logic (Math & Models)
 │    ├── elo.rs    # Elo Rating Engine
 │    ├── mps.rs    # Match Performance Score
 │    ├── ai_insights.rs # Gemini AI prompt engine
 │    ├── tournament.rs # Tournament bracket/league logic
 │    └── auth.rs   # Domain auth logic
 └── infrastructure/ # Secondary Adapters (Persistence)
      └── postgres_adapter/ # SQLx query execution modules
```

*   **API Layer:** Handles JSON serialization, HTTP status codes, and routing. It translates HTTP requests into domain commands.
*   **Domain Layer:** Pure Rust functions implementing mathematical formulas. This layer has zero knowledge of HTTP or PostgreSQL, making it highly testable.
*   **DB Layer:** Contains raw SQL queries using `sqlx` macros.

## 4. Core Domain Mathematics

### 4.1. Dynamic Elo Rating Engine

The platform calculates player skill using a highly customized Elo rating system:

*   **Expected Score ($E_a$):**
    $E_a = \frac{1}{1 + 10^{(R_b - R_a) / 400}}$
*   **Rating Update ($R_a'$):**
    $R_a' = R_a + K \cdot (S_a - E_a)$
    *Where $S_a$ is the actual score (1 for Win, 0.5 for Draw, 0 for Loss).*

**Dynamic K-Factor Scaling:**
Instead of a static $K=32$, the system scales the K-factor dynamically:
$K = K_{base} \cdot M_{margin} \cdot M_{provisional}$

*   $K_{base} = 32$
*   $M_{margin}$: Rewards decisive victories based on goal difference.
*   $M_{provisional}$: Accelerates rating changes for new players (under 10 matches).

### 4.2. Match Performance Score (MPS)

MPS is a proprietary metric (0-100) evaluating a player's in-game statistical performance, independent of the match outcome.

$MPS = C_{opp} \cdot (W_{pos} \cdot P + W_{acc} \cdot A + W_{eff} \cdot E + W_{def} \cdot D)$

*   **$C_{opp}$ (Opponent Coefficient):** Multiplier based on opponent's Elo.
*   **$P$ (Possession):** Time on the ball.
*   **$A$ (Pass Accuracy):** Successful passes / Total passes.
*   **$E$ (Shot Efficiency):** Goals / Shots on target.
*   **$D$ (Defensive Actions):** Interceptions + Tackles + Clearances.

## 5. Security & Authentication

*   **Supabase Auth:** Primary authentication provider handling user identities, OAuth, and password hashing in the database.
*   **JWT Verification:** The Flutter app sends Supabase-signed JWTs as Bearer tokens. The Rust backend decodes and cryptographically verifies these tokens using the Supabase `JWT_SECRET` to authorize API access.
*   **Offline Mode:** For offline/local testing, an Argon2id + custom JWT implementation is provided within the Rust backend as a fallback.

## 6. Deployment Infrastructure

*   **Supabase Project:** Deployed in `ap-southeast-1` (Singapore). Hosts the PostgreSQL database and handles user management.
*   **Railway Project:** Deployed in `southeast-asia` to minimize latency to the database. The Railway build pipeline executes `cargo build --release` inside a multi-stage Docker build, utilizing offline `sqlx` query caching.
