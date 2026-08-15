-- =============================================================================
-- CMTool Database — V2 Schema (Clean Redesign)
-- Migration: 20260805000000_v2_schema.sql
-- Author: Antigravity (AI) + CMTool Team
-- Date: 2026-08-05
--
-- DESCRIPTION:
--   Full schema redesign addressing 10 structural defects identified in audit.
--   Run this on a clean database (all old data has been deleted per user request).
-- =============================================================================

-- ============================================================
-- PHASE 0: DROP OLD SCHEMA (clean slate)
-- ============================================================
SET session_replication_role = replica;

DROP TABLE IF EXISTS public.player_badges          CASCADE;
DROP TABLE IF EXISTS public.badges                 CASCADE;
DROP TABLE IF EXISTS public.season_snapshots       CASCADE;
DROP TABLE IF EXISTS public.seasons                CASCADE;
DROP TABLE IF EXISTS public.squad_verifications    CASCADE;
DROP TABLE IF EXISTS public.match_disputes         CASCADE;
DROP TABLE IF EXISTS public.elo_history            CASCADE;
DROP TABLE IF EXISTS public.league_standings       CASCADE;
DROP TABLE IF EXISTS public.match_records          CASCADE;
DROP TABLE IF EXISTS public.t_matches              CASCADE;
DROP TABLE IF EXISTS public.tournament_participants CASCADE;
DROP TABLE IF EXISTS public.tournaments            CASCADE;
DROP TABLE IF EXISTS public.player_compliance      CASCADE;
DROP TABLE IF EXISTS public.player_contact_info    CASCADE;
DROP TABLE IF EXISTS public.player_profiles        CASCADE;
DROP TABLE IF EXISTS public.club_memberships       CASCADE;
DROP TABLE IF EXISTS public.clubs                  CASCADE;
DROP TABLE IF EXISTS public.users                  CASCADE;

SET session_replication_role = DEFAULT;

-- ============================================================
-- PHASE 1: CORE IDENTITY TABLES
-- ============================================================

-- 1. users — Public mirror of auth.users
CREATE TABLE public.users (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    username    TEXT        NOT NULL,
    full_name   TEXT,
    status      TEXT        NOT NULL DEFAULT 'active'
                            CHECK (status IN ('active', 'suspended', 'banned')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ,
    CONSTRAINT users_username_unique UNIQUE (username)
);

COMMENT ON TABLE  public.users IS 'Public user identity. Mirrors auth.users. Owned: username, full_name, status. NOT email/password (auth.users owns those).';
COMMENT ON COLUMN public.users.id IS 'Must match auth.users.id exactly — Supabase auth anchor.';

-- 2. clubs
CREATE TABLE public.clubs (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT        NOT NULL,
    invite_code TEXT        NOT NULL,
    owner_id    UUID        REFERENCES public.users(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMPTZ,
    CONSTRAINT clubs_invite_code_unique UNIQUE (invite_code)
);

-- 3. club_memberships — Role + per-club ELO stats
CREATE TABLE public.club_memberships (
    club_id      UUID         NOT NULL REFERENCES public.clubs(id)  ON DELETE CASCADE,
    player_id    UUID         NOT NULL REFERENCES public.users(id)  ON DELETE CASCADE,
    role         TEXT         NOT NULL DEFAULT 'player'
                              CHECK (role IN ('admin', 'organizer', 'president', 'captain', 'vice-captain', 'player')),
    skill_rating INT          NOT NULL DEFAULT 1000,
    form_rating  NUMERIC(5,2) NOT NULL DEFAULT 50.00,
    play_style   TEXT         NOT NULL DEFAULT 'Unclassified',
    status       TEXT         NOT NULL DEFAULT 'active'
                              CHECK (status IN ('active', 'inactive', 'banned')),
    joined_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    PRIMARY KEY (club_id, player_id)
);

-- ============================================================
-- PHASE 2: PLAYER PROFILE TABLES (Split from god table)
-- ============================================================

-- 4. player_profiles — Gaming identity + lifetime stats
CREATE TABLE public.player_profiles (
    user_id             UUID        PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    efootball_game_id   TEXT,
    in_game_name        TEXT,
    preferred_foot      TEXT        NOT NULL DEFAULT 'RIGHT'
                                    CHECK (preferred_foot IN ('LEFT', 'RIGHT', 'BOTH')),
    jersey_number       SMALLINT,
    system_device       TEXT,
    lifetime_matches    INT         NOT NULL DEFAULT 0,
    lifetime_wins       INT         NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. player_contact_info — Personal/contact data (sensitive)
CREATE TABLE public.player_contact_info (
    user_id         UUID        PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    email           TEXT,
    phone           TEXT,
    facebook_url    TEXT,
    facebook_handle TEXT,
    blood_group     TEXT,
    district        TEXT,
    date_of_birth   DATE,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.player_contact_info IS 'Sensitive personal contact data. RLS: readable only by self and admins.';

-- 6. player_compliance — Admin/contract data
CREATE TABLE public.player_compliance (
    user_id             UUID        PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    auth_status         TEXT        NOT NULL DEFAULT 'MEMBER'
                                    CHECK (auth_status IN ('MEMBER', 'CAPTAIN', 'COACH', 'SUSPENDED')),
    node_state          TEXT        NOT NULL DEFAULT 'ACTIVE'
                                    CHECK (node_state IN ('ACTIVE', 'INACTIVE', 'BANNED')),
    source_feed         TEXT        NOT NULL DEFAULT 'CENTRAL FEDERATION',
    registrar_joined    DATE,
    contract_start      DATE,
    contract_end        DATE,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- PHASE 3: TOURNAMENT TABLES
-- ============================================================

-- 7. tournaments
CREATE TABLE public.tournaments (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id      UUID        NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
    name         TEXT        NOT NULL,
    format_type  TEXT        NOT NULL
                             CHECK (format_type IN ('knockout', 'round_robin', 'league', 'group_knockout')),
    status       TEXT        NOT NULL DEFAULT 'draft'
                             CHECK (status IN ('draft', 'active', 'completed', 'cancelled')),
    rules_config JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at   TIMESTAMPTZ
);

COMMENT ON TABLE public.tournaments IS 'rules_config: format params only — NOT participant_ids (those live in tournament_participants).';

-- 8. tournament_participants — Normalized (replaces JSONB participant_ids array)
CREATE TABLE public.tournament_participants (
    tournament_id   UUID        NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
    player_id       UUID        NOT NULL REFERENCES public.users(id)       ON DELETE CASCADE,
    seed_rank       SMALLINT,
    group_name      TEXT,
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (tournament_id, player_id)
);

COMMENT ON TABLE public.tournament_participants IS 'Normalized junction: replaces JSONB participant_ids. Enables indexed membership queries.';

-- 9. t_matches — NO circular FK (match_record_id removed from here)
CREATE TABLE public.t_matches (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id   UUID        NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
    round_number    SMALLINT    NOT NULL,
    match_number    INT         NOT NULL,
    group_name      TEXT,
    player_1_id     UUID        REFERENCES public.users(id) ON DELETE SET NULL,
    player_2_id     UUID        REFERENCES public.users(id) ON DELETE SET NULL,
    player_1_score  SMALLINT,
    player_2_score  SMALLINT,
    winner_id       UUID        REFERENCES public.users(id) ON DELETE SET NULL,
    status          TEXT        NOT NULL DEFAULT 'scheduled'
                                CHECK (status IN ('scheduled', 'completed', 'disputed', 'forfeit', 'bye')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT t_matches_unique_slot UNIQUE (tournament_id, round_number, match_number)
);

COMMENT ON TABLE public.t_matches IS 'Circular FK removed. FK direction: match_records.t_match_id → t_matches.id (one-way only).';

-- ============================================================
-- PHASE 4: MATCH TRACKING
-- ============================================================

-- 10. match_records — Primary OCR match stat record
CREATE TABLE public.match_records (
    id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Context
    club_id              UUID         NOT NULL REFERENCES public.clubs(id)   ON DELETE CASCADE,
    player_id            UUID         NOT NULL REFERENCES public.users(id)   ON DELETE CASCADE,
    opponent_id          UUID         NOT NULL REFERENCES public.users(id)   ON DELETE CASCADE,
    partner_id           UUID         REFERENCES public.users(id)            ON DELETE SET NULL,
    opponent_partner_id  UUID         REFERENCES public.users(id)            ON DELETE SET NULL,
    t_match_id           UUID         REFERENCES public.t_matches(id)        ON DELETE SET NULL,
    match_type           TEXT         NOT NULL DEFAULT 'friendly'
                                      CHECK (match_type IN ('friendly', 'league', 'tournament_final')),
    -- Outcome
    result               TEXT         NOT NULL CHECK (result IN ('win', 'draw', 'loss')),
    goals_for            SMALLINT     NOT NULL,
    goals_against        SMALLINT     NOT NULL,
    -- eFootball Performance Stats
    possession           NUMERIC(4,1) NOT NULL,
    passes_completed     SMALLINT     NOT NULL,
    passes_attempted     SMALLINT     NOT NULL,
    shots_on_target      SMALLINT     NOT NULL,
    shots_total          SMALLINT     NOT NULL,
    interceptions        SMALLINT     NOT NULL,
    fouls                SMALLINT     NOT NULL DEFAULT 0,
    offsides             SMALLINT     NOT NULL DEFAULT 0,
    corners              SMALLINT     NOT NULL DEFAULT 0,
    free_kicks           SMALLINT     NOT NULL DEFAULT 0,
    crosses              SMALLINT     NOT NULL DEFAULT 0,
    tackles              SMALLINT     NOT NULL DEFAULT 0,
    saves                SMALLINT     NOT NULL DEFAULT 0,
    -- OCR & Verification
    ocr_confidence       NUMERIC(4,1) NOT NULL DEFAULT 100.0,
    screenshot_hash      TEXT         NOT NULL,
    screenshot_url       TEXT,
    verification_status  TEXT         NOT NULL DEFAULT 'approved'
                                      CHECK (verification_status IN ('pending', 'approved', 'disputed')),
    verified_by_id       UUID         REFERENCES public.users(id) ON DELETE SET NULL,
    -- Audit
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    deleted_at           TIMESTAMPTZ,
    CONSTRAINT match_records_screenshot_unique UNIQUE (screenshot_hash)
);

COMMENT ON TABLE public.match_records IS 'club_id is NOT NULL. t_match_id is nullable (NULL for friendly matches).';

-- 11. elo_history — UUID PK, NOT NULL club_id, generated delta
CREATE TABLE public.elo_history (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id          UUID        NOT NULL REFERENCES public.clubs(id)        ON DELETE CASCADE,
    player_id        UUID        NOT NULL REFERENCES public.users(id)        ON DELETE CASCADE,
    match_record_id  UUID        REFERENCES public.match_records(id)         ON DELETE SET NULL,
    rating_before    INT         NOT NULL,
    rating_after     INT         NOT NULL,
    delta            INT         GENERATED ALWAYS AS (rating_after - rating_before) STORED,
    recorded_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.elo_history IS 'delta is a generated column (rating_after - rating_before). UUID PK for consistency.';

-- ============================================================
-- PHASE 5: STANDINGS & DISPUTES
-- ============================================================

-- 12. league_standings — goal_diff and points are GENERATED COLUMNS
CREATE TABLE public.league_standings (
    id                       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id            UUID        NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
    player_id                UUID        NOT NULL REFERENCES public.users(id)       ON DELETE CASCADE,
    group_name               TEXT,
    played                   SMALLINT    NOT NULL DEFAULT 0,
    won                      SMALLINT    NOT NULL DEFAULT 0,
    drawn                    SMALLINT    NOT NULL DEFAULT 0,
    lost                     SMALLINT    NOT NULL DEFAULT 0,
    goals_for                INT         NOT NULL DEFAULT 0,
    goals_against            INT         NOT NULL DEFAULT 0,
    goal_diff                INT         GENERATED ALWAYS AS (goals_for - goals_against) STORED,
    points                   INT         GENERATED ALWAYS AS (won * 3 + drawn)           STORED,
    last_processed_match_id  UUID        REFERENCES public.t_matches(id) ON DELETE SET NULL,
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT standings_unique_player UNIQUE (tournament_id, player_id)
);

COMMENT ON TABLE public.league_standings IS 'goal_diff and points are GENERATED — cannot drift. last_processed_match_id is now formally FK-constrained.';

-- 13. match_disputes
CREATE TABLE public.match_disputes (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    match_record_id         UUID        NOT NULL REFERENCES public.match_records(id) ON DELETE CASCADE,
    raised_by               UUID        NOT NULL REFERENCES public.users(id)         ON DELETE CASCADE,
    reason                  TEXT        NOT NULL,
    status                  TEXT        NOT NULL DEFAULT 'open'
                                        CHECK (status IN ('open', 'resolved', 'dismissed')),
    counter_screenshot_url  TEXT,
    resolved_by             UUID        REFERENCES public.users(id) ON DELETE SET NULL,
    resolution_notes        TEXT,
    resolved_at             TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- PHASE 6: PERFORMANCE INDEXES
-- ============================================================

CREATE INDEX idx_match_records_club_player    ON public.match_records        (club_id, player_id, created_at DESC);
CREATE INDEX idx_match_records_screenshot     ON public.match_records        (screenshot_hash);
CREATE INDEX idx_match_records_t_match        ON public.match_records        (t_match_id) WHERE t_match_id IS NOT NULL;
CREATE INDEX idx_elo_history_club_player      ON public.elo_history          (club_id, player_id, recorded_at DESC);
CREATE INDEX idx_t_matches_tournament_status  ON public.t_matches            (tournament_id, status);
CREATE INDEX idx_t_matches_match_number       ON public.t_matches            (tournament_id, match_number);
CREATE INDEX idx_league_standings_tournament  ON public.league_standings     (tournament_id, points DESC, goal_diff DESC);
CREATE INDEX idx_club_memberships_skill       ON public.club_memberships     (club_id, skill_rating DESC);
CREATE INDEX idx_participants_player          ON public.tournament_participants (player_id, tournament_id);

-- ============================================================
-- PHASE 7: ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.users                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clubs                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.club_memberships       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_contact_info    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_compliance      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournaments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.t_matches              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_records          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.elo_history            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_standings       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_disputes         ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'auth') THEN

        -- users
        CREATE POLICY "users_select" ON public.users FOR SELECT TO authenticated USING (true);
        CREATE POLICY "users_update_self" ON public.users FOR UPDATE TO authenticated
            USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

        -- clubs
        CREATE POLICY "clubs_select" ON public.clubs FOR SELECT TO authenticated USING (true);
        CREATE POLICY "clubs_insert" ON public.clubs FOR INSERT TO authenticated WITH CHECK (auth.uid() = owner_id);
        CREATE POLICY "clubs_update" ON public.clubs FOR UPDATE TO authenticated USING (auth.uid() = owner_id);

        -- club_memberships
        CREATE POLICY "memberships_select" ON public.club_memberships FOR SELECT TO authenticated
            USING (EXISTS (SELECT 1 FROM public.club_memberships cm WHERE cm.club_id = club_memberships.club_id AND cm.player_id = auth.uid()));
        CREATE POLICY "memberships_insert" ON public.club_memberships FOR INSERT TO authenticated
            WITH CHECK (auth.uid() = player_id);

        -- player_profiles
        CREATE POLICY "profiles_select" ON public.player_profiles FOR SELECT TO authenticated USING (true);
        CREATE POLICY "profiles_write_self" ON public.player_profiles FOR ALL TO authenticated
            USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

        -- player_contact_info (private)
        CREATE POLICY "contact_self_or_admin" ON public.player_contact_info FOR ALL TO authenticated
            USING (auth.uid() = user_id OR EXISTS (
                SELECT 1 FROM public.club_memberships cm
                JOIN public.club_memberships tcm ON cm.club_id = tcm.club_id
                WHERE cm.player_id = auth.uid() AND cm.role IN ('admin','organizer')
                  AND tcm.player_id = player_contact_info.user_id
            ));

        -- player_compliance (private)
        CREATE POLICY "compliance_self_or_admin" ON public.player_compliance FOR ALL TO authenticated
            USING (auth.uid() = user_id OR EXISTS (
                SELECT 1 FROM public.club_memberships cm
                JOIN public.club_memberships tcm ON cm.club_id = tcm.club_id
                WHERE cm.player_id = auth.uid() AND cm.role IN ('admin','organizer')
                  AND tcm.player_id = player_compliance.user_id
            ));

        -- tournaments
        CREATE POLICY "tournaments_select" ON public.tournaments FOR SELECT TO authenticated
            USING (EXISTS (SELECT 1 FROM public.club_memberships cm WHERE cm.club_id = tournaments.club_id AND cm.player_id = auth.uid()));
        CREATE POLICY "tournaments_write_admins" ON public.tournaments FOR ALL TO authenticated
            USING (EXISTS (SELECT 1 FROM public.club_memberships cm WHERE cm.club_id = tournaments.club_id AND cm.player_id = auth.uid() AND cm.role IN ('admin','organizer')));

        -- tournament_participants
        CREATE POLICY "participants_select" ON public.tournament_participants FOR SELECT TO authenticated
            USING (EXISTS (
                SELECT 1 FROM public.tournaments t
                JOIN public.club_memberships cm ON cm.club_id = t.club_id
                WHERE t.id = tournament_participants.tournament_id AND cm.player_id = auth.uid()
            ));

        -- t_matches
        CREATE POLICY "t_matches_select" ON public.t_matches FOR SELECT TO authenticated
            USING (EXISTS (
                SELECT 1 FROM public.tournaments t
                JOIN public.club_memberships cm ON cm.club_id = t.club_id
                WHERE t.id = t_matches.tournament_id AND cm.player_id = auth.uid()
            ));

        -- match_records
        CREATE POLICY "match_records_select" ON public.match_records FOR SELECT TO authenticated
            USING (EXISTS (SELECT 1 FROM public.club_memberships cm WHERE cm.club_id = match_records.club_id AND cm.player_id = auth.uid()));
        CREATE POLICY "match_records_insert" ON public.match_records FOR INSERT TO authenticated
            WITH CHECK (auth.uid() = player_id);

        -- elo_history
        CREATE POLICY "elo_select" ON public.elo_history FOR SELECT TO authenticated
            USING (EXISTS (SELECT 1 FROM public.club_memberships cm WHERE cm.club_id = elo_history.club_id AND cm.player_id = auth.uid()));

        -- league_standings
        CREATE POLICY "standings_select" ON public.league_standings FOR SELECT TO authenticated
            USING (EXISTS (
                SELECT 1 FROM public.tournaments t
                JOIN public.club_memberships cm ON cm.club_id = t.club_id
                WHERE t.id = league_standings.tournament_id AND cm.player_id = auth.uid()
            ));

        -- match_disputes
        CREATE POLICY "disputes_select" ON public.match_disputes FOR SELECT TO authenticated
            USING (auth.uid() = raised_by OR EXISTS (
                SELECT 1 FROM public.match_records mr
                WHERE mr.id = match_disputes.match_record_id
                  AND (mr.player_id = auth.uid() OR mr.opponent_id = auth.uid())
            ));
        CREATE POLICY "disputes_insert" ON public.match_disputes FOR INSERT TO authenticated
            WITH CHECK (auth.uid() = raised_by);

    END IF;
END $$;
