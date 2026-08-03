# System Architecture & Design

This document provides a high-level overview of the eFootball Club Management & Analytics Tool's system architecture, including the backend structure, domain mathematics, database ERD, and security design.

## 1. High-Level System Architecture

The project is built on a modern, typed, low-cost stack:

*   **Mobile Client (Frontend):** Flutter (Dart) app built for iOS, Android, and Desktop. It uses Riverpod for state management, Dio for REST API calls, and the Supabase Flutter SDK for real-time authentication and database synchronization.
*   **API Server (Backend):** Rust (Axum framework) server providing a high-performance RESTful JSON API.
*   **Database (Persistence):** PostgreSQL hosted on Supabase. It uses Supabase Auth for identity management, row-level security (RLS), and acts as the central source of truth.
*   **Hosting / Deployment:** The Rust backend is packaged in a lean Docker container (under 50MB) and deployed to Railway.

## 2. Hexagonal Architecture (Backend)

The Rust backend is structured using principles of Hexagonal Architecture (Ports and Adapters) to isolate business logic from external concerns:

```text
src/
 ├── api/           # Primary Adapters (HTTP Transport)
 │    ├── routes.rs # Axum route handlers & REST endpoints
 │    └── mod.rs
 ├── domain/        # Core Business Logic (Math & Models)
 │    ├── elo.rs    # Elo Rating Engine
 │    ├── mps.rs    # Match Performance Score
 │    ├── ai.rs     # Gemini AI prompt engine
 │    └── mod.rs
 ├── db/            # Secondary Adapters (Persistence)
 │    ├── repository.rs # SQLx query execution
 │    └── models.rs     # Database structs
 └── auth.rs        # JWT and Argon2id Security Middleware
```

*   **API Layer:** Handles JSON serialization, HTTP status codes, and routing. It translates HTTP requests into domain commands.
*   **Domain Layer:** Pure Rust functions implementing mathematical formulas. This layer has zero knowledge of HTTP or PostgreSQL, making it highly testable.
*   **DB Layer:** Contains raw SQL queries using `sqlx` macros.

## 3. Core Domain Mathematics

### 3.1. Dynamic Elo Rating Engine

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

### 3.2. Match Performance Score (MPS)

MPS is a proprietary metric (0-100) evaluating a player's in-game statistical performance, independent of the match outcome.

$MPS = C_{opp} \cdot (W_{pos} \cdot P + W_{acc} \cdot A + W_{eff} \cdot E + W_{def} \cdot D)$

*   **$C_{opp}$ (Opponent Coefficient):** Multiplier based on opponent's Elo.
*   **$P$ (Possession):** Time on the ball.
*   **$A$ (Pass Accuracy):** Successful passes / Total passes.
*   **$E$ (Shot Efficiency):** Goals / Shots on target.
*   **$D$ (Defensive Actions):** Interceptions + Tackles + Clearances.

## 4. Security & Authentication

*   **Supabase Auth:** Primary authentication provider handling user identities, OAuth, and password hashing in the database.
*   **JWT Verification:** The Flutter app sends Supabase-signed JWTs as Bearer tokens. The Rust backend decodes and cryptographically verifies these tokens using the Supabase `JWT_SECRET` to authorize API access.
*   **Offline Mode:** For offline/local testing, an Argon2id + custom JWT implementation is provided within the Rust backend as a fallback.

## 5. Deployment Infrastructure

*   **Supabase Project:** Deployed in `ap-southeast-1` (Singapore). Hosts the PostgreSQL database and handles user management.
*   **Railway Project:** Deployed in `southeast-asia` to minimize latency to the database. The Railway build pipeline executes `cargo build --release` inside a multi-stage Docker build, utilizing offline `sqlx` query caching.
