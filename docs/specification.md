# Technical Specification: eFootball Club Management & Analytics

## 1. System Overview & Architectural Strategy

The system is designed as a statically typed, ultra-low-cost monolith using Hexagonal Architecture (Ports and Adapters). This decouples the core domain logic (analytics, Elo math, tournament bracket generation) from the infrastructure layer (databases, AI APIs).

### V1 Core Technology Stack (Optimized for $0–$5/month)

- **Mobile Client**: Flutter (Dart). Compiles to native ARM for iOS and Android. Handles state via Riverpod/BLoC. Includes offline SQLite storage (Drift/Hive) for queuing match uploads.
- **OCR Engine**: On-device Google ML Kit. Shifts the heavy compute burden to the user's phone, completely eliminating cloud image processing costs.
- **Backend API**: Rust using the Axum web framework. Provides massive concurrency with virtually zero memory overhead.
- **Database & Auth**: Supabase (PostgreSQL, built-in Auth, S3-compatible Storage for match screenshot backups).
- **AI Engine**: Google Gemini API (utilizing the generous free tier for text-based JSON-to-insights generation) with a deterministic fallback engine.

---

## 2. Core Feature Modules

### A. Player Performance Analytics & Verification Pipeline

Converts temporary eFootball post-match screenshots into a permanent, tamper-resistant digital career.

- **On-Device OCR Extraction**: The Flutter client runs ML Kit to extract match stats (Possession, Passes, Shots on Target, Interceptions, etc.) and packages them into a JSON payload.
- **OCR Confidence Thresholding**: If ML Kit confidence drops below 85%, the Flutter app presents a simple text-input correction form with the parsed values, highlighting low-confidence fields in red for easy manual correction before sending.
- **Logical Match Deduplication**: The backend detects duplicate match submissions by checking for existing records with the exact same `(player_1, player_2, result)` within a 2-hour window. If found, instead of rejecting the second upload, it automatically marks the match as "confirmed" by the opponent.
- **Validation Gateway**: The Rust backend validates the JSON payload against strict logical rules before saving (e.g., `passes_success` $\le$ `passes_total`, `shots_on_target` $\le$ `shots_total`).
- **Dual-Player Confirmation Flow**: For tournament or competitive league matches, match uploads enter a `Pending Verification` state until the opponent confirms the result or 24 hours pass without dispute.
- **Play Style Classifier**: A cron job evaluates a player's last 20 matches. It assigns tags (e.g., "Possession Master" if Average Possession > 60% and Pass Accuracy > 85%).
- **Club Leaderboards**: Real-time rankings for Highest Skill Rating, Best Win Rate, Most Consistent Player, etc.

---

### B. Mathematical Formulations & The Three Rating Systems

Calculated instantly via Rust upon a successful match upload.

#### 1. Skill Rating (Dynamic Elo System)
Measures long-term strength. Expected score $E$ for a player against opponent is calculated as:

$$E = \frac{1}{1 + 10^{(R_{opp} - R_{player}) / 400}}$$

The new rating $R_{new}$ is then adjusted based on actual result $S$ (Win = 1.0, Draw = 0.5, Loss = 0.0):

$$R_{new} = R_{old} + K \cdot (S - E)$$

Where the dynamic $K$-factor is computed as:

$$K = K_{base} \cdot M_{margin} \cdot M_{provisional}$$

- $K_{base}$: $40$ for Tournament/League Finals, $32$ for standard League matches, $16$ for Friendlies.
- $M_{margin} = \ln(1 + |\Delta G|)$ where $\Delta G = \text{Goals For} - \text{Goals Against}$.
- $M_{provisional} = 1.5$ for players with fewer than 10 recorded matches.

*Co-op (2v2) Elo Calculation*: Team Elo is defined as $R_{team} = \frac{R_{P1} + R_{P2}}{2}$. The resulting rating delta $\Delta R$ is distributed to both team members weighted inversely by their baseline ratings to prevent rating boosting.

#### 2. Match Performance Score (MPS, 0–100)
Evaluates a single match by comparing extracted stats against the player's historical averages, adjusted for opponent difficulty.
*Note: MPS calculation is disabled for Co-op (2v2) matches, as standard OCR team stats cannot accurately attribute individual possession and passing metrics to a specific player.*

$$\text{MPS} = \min\left(100, \left( w_1 \cdot S_{possession} + w_2 \cdot S_{passing} + w_3 \cdot S_{efficiency} + w_4 \cdot S_{defense} \right) \times C_{opp} \right)$$

- **Weights**: $w_1 = 0.20$ (Possession), $w_2 = 0.30$ (Pass Accuracy), $w_3 = 0.30$ (Shot Efficiency), $w_4 = 0.20$ (Defensive Actions).
- **Sub-scores**:
  - $S_{possession} = \text{Possession Percentage}$
  - $S_{passing} = \frac{\text{Passes Completed}}{\max(1, \text{Passes Attempted})} \times 100$
  - $S_{efficiency} = \frac{\text{Goals Scored}}{\max(1, \text{Shots on Target})} \times 100$
  - $S_{defense} = \min(100, \text{Interceptions} \times 10)$
- **Opponent Coefficient ($C_{opp}$)**: $1.0 + \frac{R_{opp} - R_{player}}{2000}$ (clamped between $0.8$ and $1.2$).

#### 3. Form Rating
An Exponentially Weighted Moving Average (EWMA) of the Match Performance Score (MPS) over recent matches, prioritizing recent form over older results.

---

### C. Tournament & League Operations

An orchestration layer for internal club events and external scrimmages.

- **Automated Bracket Generator**: Uses the Elo `skill_rating` to seed Knockout tournaments automatically.
- **Circle Method Scheduler**: Generates balanced fixtures for Round-Robin (League) group stages.
- **Event-Driven Advancement**: When a player uploads a `Match_Record` linked to an active `t_match_id`, the system automatically advances the Knockout bracket or recalculates `League_Standings`.
- **Dispute Resolution Gateway**: Allows players to flag incorrect submissions and optionally upload a counter-evidence screenshot. This places the match into an admin review queue featuring a side-by-side dashboard of both claims.

---

### D. AI-Powered Coaching Insights & Fallback Engine

Uses LLMs to generate natural language reports based strictly on JSON data.

- **Match Reports**: *"You won 2–0 while maintaining 64% possession. Your passing exceeded your season average by 5%."*
- **Strength/Weakness Analysis**: *"Your pass accuracy decreases slightly against elite opponents."*
- **Strict Anti-Hallucination Prompting**: The LLM is explicitly forbidden from mentioning goal timings, goalscorers, formations, or substitutions, as these cannot be extracted from the standard OCR screenshot. Enforced via `response_format: { type: "json_object" }`.
- **Deterministic Rust Fallback**: When `enable_ai_insights` feature flag is set to `false` (during API rate limits or offline mode), Rust runs a rule-based template engine to produce structured performance feedback without calling cloud APIs.

---

### E. Seasons & Historical Archives

Organizes club activity into discrete seasons (e.g., "Season 3: July–September 2026").
At season end, snapshot all ratings and standings into an archive table, preventing rating stagnation and creating competitive milestones.

### F. Head-to-Head Rivalry Tracker

Automatically computes and surfaces H2H records between any two players in the same club: total matches, win/draw/loss split, average goal difference, and Elo delta across their matchups.

### G. Achievement & Badge System

Awards badges for milestones: "First 50 Matches", "10-Win Streak", "Clean Sheet Master" (5 matches with 0 goals against). Creates social currency and drives engagement.

### H. Match Prediction Engine

Before a tournament fixture, displays the predicted win probability for each player using their current Elo ratings (E formula), recent form, and H2H record.

### I. Community & Engagement (Activity Feed, Multi-Club, Shareable Cards)

- **Activity Feed**: Chronological feed showing match results, rating milestones, and earned badges.
- **Multi-Club Membership**: Players can join multiple clubs (e.g., local neighborhood club and university club).
- **Shareable Player Cards**: Auto-generates "Ultimate Team" style player cards based on rating and form for easy social sharing.

---

## 3. Database Schema (PostgreSQL)

### Table Structures & DDL

```sql
-- 1. Clubs Table
CREATE TABLE Clubs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    invite_code VARCHAR(10) UNIQUE NOT NULL,
    owner_id UUID, -- Setup later to avoid circular FK
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 2. Users Table
CREATE TABLE Users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Alter Clubs to add FK once Users exists
ALTER TABLE Clubs ADD CONSTRAINT fk_owner FOREIGN KEY (owner_id) REFERENCES Users(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;

-- 2b. Club Memberships (Multi-Club Support)
CREATE TABLE Club_Memberships (
    player_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    club_id UUID REFERENCES Clubs(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'player', -- 'admin', 'organizer', 'player'
    skill_rating INT DEFAULT 1000,
    form_rating NUMERIC(5,2) DEFAULT 50.00,
    play_style VARCHAR(50) DEFAULT 'Unclassified',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (player_id, club_id)
);

-- 3. Player Profiles (Global Lifetime Stats)
CREATE TABLE Player_Profiles (
    user_id UUID PRIMARY KEY REFERENCES Users(id) ON DELETE CASCADE,
    lifetime_matches INT DEFAULT 0,
    lifetime_wins INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Tournaments
CREATE TABLE Tournaments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID REFERENCES Clubs(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    format_type VARCHAR(20) NOT NULL, -- 'knockout', 'round_robin', 'swiss', 'league'
    status VARCHAR(20) DEFAULT 'draft', -- 'draft', 'active', 'completed'
    rules_config JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 5. Tournament Matches
CREATE TABLE T_Matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID REFERENCES Tournaments(id) ON DELETE CASCADE,
    player_1_id UUID REFERENCES Users(id),
    player_2_id UUID REFERENCES Users(id),
    round_number INT NOT NULL,
    status VARCHAR(20) DEFAULT 'scheduled', -- 'scheduled', 'completed', 'disputed'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Match Records
CREATE TABLE Match_Records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID REFERENCES Clubs(id) ON DELETE CASCADE,
    player_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    opponent_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    partner_id UUID REFERENCES Users(id) ON DELETE SET NULL, -- for 2v2
    opponent_partner_id UUID REFERENCES Users(id) ON DELETE SET NULL, -- for 2v2
    t_match_id UUID REFERENCES T_Matches(id) ON DELETE SET NULL,
    match_type VARCHAR(20) NOT NULL DEFAULT 'friendly', -- 'friendly', 'league', 'tournament_final'
    result VARCHAR(10) NOT NULL, -- 'win', 'draw', 'loss'
    goals_for INT NOT NULL,
    goals_against INT NOT NULL,
    possession NUMERIC(4,1) NOT NULL,
    passes_completed INT NOT NULL,
    passes_attempted INT NOT NULL,
    shots_on_target INT NOT NULL,
    shots_total INT NOT NULL,
    interceptions INT NOT NULL,
    ocr_confidence NUMERIC(4,1) DEFAULT 100.0,
    screenshot_hash VARCHAR(64) UNIQUE NOT NULL,
    screenshot_url TEXT,
    verification_status VARCHAR(20) DEFAULT 'approved', -- 'pending', 'approved', 'disputed'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Link T_Matches to Match_Records (deferred circular reference handling or simply store in Match_Records)
ALTER TABLE T_Matches ADD COLUMN match_record_id UUID REFERENCES Match_Records(id) ON DELETE SET NULL;

-- 7. Elo Rating History
CREATE TABLE Elo_History (
    id BIGSERIAL PRIMARY KEY,
    player_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    match_record_id UUID REFERENCES Match_Records(id) ON DELETE CASCADE,
    rating_before INT NOT NULL,
    rating_after INT NOT NULL,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. League Standings
CREATE TABLE League_Standings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID REFERENCES Tournaments(id) ON DELETE CASCADE,
    player_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    played INT DEFAULT 0,
    won INT DEFAULT 0,
    drawn INT DEFAULT 0,
    lost INT DEFAULT 0,
    goals_for INT DEFAULT 0,
    goals_against INT DEFAULT 0,
    goal_diff INT DEFAULT 0,
    points INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tournament_id, player_id)
);



-- 10. Match Disputes
CREATE TABLE Match_Disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_record_id UUID REFERENCES Match_Records(id) ON DELETE CASCADE,
    raised_by UUID REFERENCES Users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'open', -- 'open', 'resolved', 'dismissed'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Seasons & Snapshots
CREATE TABLE Seasons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID REFERENCES Clubs(id),
    name VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE Season_Snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    season_id UUID REFERENCES Seasons(id),
    player_id UUID REFERENCES Users(id),
    final_skill_rating INT NOT NULL,
    final_form_rating NUMERIC(5,2),
    matches_played INT,
    win_rate NUMERIC(5,2)
);

-- 12. Badges System
CREATE TABLE Badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url TEXT,
    criteria JSONB NOT NULL
);

CREATE TABLE Player_Badges (
    player_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    badge_id UUID REFERENCES Badges(id),
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (player_id, badge_id)
);
```

### Essential Indexes

```sql
CREATE INDEX idx_match_records_player ON Match_Records(player_id, created_at DESC);
CREATE INDEX idx_elo_history_player ON Elo_History(player_id, recorded_at DESC);
CREATE INDEX idx_league_standings_tournament ON League_Standings(tournament_id, points DESC);
```

### Row Level Security (RLS) Security Policies

*Concrete SQL implementation for standard policies:*

```sql
-- Enable RLS
ALTER TABLE Match_Records ENABLE ROW LEVEL SECURITY;
ALTER TABLE Tournaments ENABLE ROW LEVEL SECURITY;

-- Match_Records: Read accessible to users within the same club (via memberships).
CREATE POLICY "Matches visible to club members" ON Match_Records FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM Club_Memberships cm1 
    JOIN Club_Memberships cm2 ON cm1.club_id = cm2.club_id
    WHERE cm1.player_id = Match_Records.player_id AND cm2.player_id = auth.uid()
  )
);

-- Match_Records: Write restricted to authenticated user_id == player_id
CREATE POLICY "Users can insert their own matches" ON Match_Records FOR INSERT
WITH CHECK (auth.uid() = player_id);

-- Tournaments: Insert/Update restricted to Users where role IN ('admin', 'organizer')
CREATE POLICY "Admins manage tournaments" ON Tournaments FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM Club_Memberships 
    WHERE player_id = auth.uid() AND club_id = Tournaments.club_id AND role IN ('admin', 'organizer')
  )
);
```

---

## 4. API & Network Communication Architecture

### General Error Contract
All API errors return a standard JSON envelope:
```json
{
  "error": {
    "code": "DUPLICATE_SCREENSHOT",
    "message": "A match with this screenshot hash already exists.",
    "details": {}
  }
}
```

### REST API Endpoints (Rust / Axum Backend)

| Method | Endpoint | Description |
| --- | --- | --- |
| `POST` | `/api/v1/auth/register` | User registration and profile creation. |
| `POST` | `/api/v1/clubs` | Create a new club (user becomes owner). |
| `POST` | `/api/v1/clubs/{id}/join` | Join a club via invite code. |
| `POST` | `/api/v1/matches/ocr-submit` | Submit OCR extracted JSON payload + SHA-256 hash. Returns validated `Match_Record` & updated Elo. |
| `POST` | `/api/v1/matches/{id}/confirm` | Dual-player flow: Opponent confirms match result to exit Pending state. |
| `GET` | `/api/v1/tournaments/{id}/bracket` | Retrieves current bracket structure, fixtures, and standings. |
| `POST` | `/api/v1/tournaments` | Create a new tournament. |

| `GET` | `/api/v1/players/{id}/analytics` | Retrieves MPS breakdown, Form Rating (SMA), and Play Style tags. |
| `GET` | `/api/v1/leaderboards/{club_id}` | Retrieves club rankings (Elo, Form, Badges). |
| `POST` | `/api/v1/disputes` | Raise a dispute against a pending or completed match. |
| `POST` | `/api/v1/admin/feature-flags` | Toggle feature flags (e.g., AI Insights, Live Standings). |

### Real-Time Updates (WebSockets / Supabase Realtime)
- Flutter client subscribes to topic `tournament:{id}:live`.
- **Payload Schema**: Emits standard JSON events like `{ "event": "MATCH_UPDATED", "payload": { "t_match_id": "...", "status": "completed" }}`.
- Upon Axum bracket calculation or match submission, updates are broadcasted to all connected clients, refreshing tournament brackets instantly without polling.

### Offline Sync Protocol (Flutter Client)
- Screenshots and OCR payloads generated while offline are cached locally in SQLite (Drift/Hive).
- A Flutter background service (`workmanager`) syncs pending uploads automatically upon regaining internet access.

---

## 5. Scale-Up Strategy (Hexagonal Architecture)

The system adopts an **Evolutionary Architecture** approach—built to operate lean and free today, but engineered so it won't require a complete rewrite if scaled up with cloud credits tomorrow.

### A. The "Plug and Play" Rust Codebase (Ports & Adapters)

Code is never permanently locked to one specific service (like Supabase). Instead, Rust `Traits` (interfaces) define *what* the system does, not *how* it does it.

- **The Trait (The Port)**: Defines an interface like `DatabaseClient` with functions such as `save_match_record()`.
- **The V1 Adapter (Free)**: An implementation of that trait using `SupabaseAdapter`.
- **The Scale-Up (Paid)**: Developers write an `AwsRdsAdapter` and change a single line of server configuration to swap implementations. The core math and tournament logic remain completely untouched.

### B. The Scale-Up Roadmap

| Layer | V1: Free & Lean (Current) | V2: Sponsored & Scaled (Future) | How to Transition |
| --- | --- | --- | --- |
| **Hosting** | $4/mo Hetzner VPS (Single Server). | **AWS Fargate** or **Kubernetes**. | Because the Rust app is stateless, wrap it in a **Docker container**. AWS can spin up 50 copies of the container to handle traffic spikes, then scale back down to 1 automatically. |
| **Database** | Supabase PostgreSQL (Free Tier). | **AWS Aurora (Serverless Postgres)** + **Redis Cache**. | Export the Supabase SQL dump and import directly into AWS. Since both are standard Postgres, no table schemas change. Add a Redis layer in front to cache high-traffic requests like `League_Standings`. |
| **OCR Processing** | Google ML Kit (On-Device). | **Hybrid (On-Device + Cloud Fallback)**. | Keep fast on-device OCR as the default. Route failed or low-confidence device scans to a paid **AWS Textract** API for guaranteed accuracy. |
| **AI Insights** | Gemini API (Free Tier). | **OpenAI GPT-4o (Dedicated Batch Processing)**. | Swap the API key. Instead of running AI live (preventing timeouts under heavy load), introduce an asynchronous message queue (like AWS SQS) that processes match reports in the background and sends push notifications when ready. |

### C. Feature Flags for Traffic Spikes

If a massive influx of users floods the application at once, API rate limits on free tier services might be reached before servers can be upgraded.

A **Feature Flag** system backed by a simple `system_config` table/JSON loaded into Rust's memory allows admins to toggle features directly from an admin dashboard without releasing app updates:

- `"enable_ai_insights": false` — Instantly stops calling the Gemini API to prevent rate limits, activating the deterministic Rust fallback engine.
- `"enable_live_standings": false` — Updates tournament brackets periodically (e.g., every 10 minutes instead of live queries), preserving database performance.

This guarantees that core functionality—uploading matches and recording stats—never goes down, even if optional background features are temporarily disabled.