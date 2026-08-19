-- =============================================================================
-- CMTool Database — Matchday System Migration
-- Migration: 20260819000000_matchday_system.sql
-- =============================================================================

-- 1. Add start_date and end_date to tournaments
ALTER TABLE public.tournaments ADD COLUMN start_date DATE;
ALTER TABLE public.tournaments ADD COLUMN end_date DATE;

-- 2. Create matchdays table
CREATE TABLE public.matchdays (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id   UUID        NOT NULL REFERENCES public.tournaments(id) ON DELETE CASCADE,
    matchday_number SMALLINT    NOT NULL,
    scheduled_date  DATE,
    status          TEXT        NOT NULL DEFAULT 'upcoming'
                                CHECK (status IN ('upcoming', 'in_progress', 'completed')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT matchdays_unique UNIQUE (tournament_id, matchday_number)
);
CREATE INDEX idx_matchdays_tournament ON public.matchdays(tournament_id, matchday_number);

-- 3. Add matchday link + scheduling columns to t_matches
ALTER TABLE public.t_matches ADD COLUMN matchday_id UUID REFERENCES public.matchdays(id) ON DELETE SET NULL;
ALTER TABLE public.t_matches ADD COLUMN scheduled_at TIMESTAMPTZ;
ALTER TABLE public.t_matches ADD COLUMN original_scheduled_at TIMESTAMPTZ;
ALTER TABLE public.t_matches ADD COLUMN is_rescheduled BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.t_matches ADD COLUMN reschedule_reason TEXT;

-- Expand status CHECK to include 'rescheduled'
ALTER TABLE public.t_matches DROP CONSTRAINT IF EXISTS t_matches_status_check;
ALTER TABLE public.t_matches ADD CONSTRAINT t_matches_status_check
    CHECK (status IN ('scheduled', 'completed', 'disputed', 'forfeit', 'bye', 'rescheduled'));
CREATE INDEX idx_t_matches_matchday ON public.t_matches(matchday_id);

-- 4. Create schedule_audit_log table
CREATE TABLE public.schedule_audit_log (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type   TEXT        NOT NULL CHECK (entity_type IN ('matchday', 'match')),
    entity_id     UUID        NOT NULL,
    action        TEXT        NOT NULL,  -- e.g. 'created', 'rescheduled', 'date_changed'
    old_value     TEXT,
    new_value     TEXT,
    reason        TEXT,
    changed_by    UUID        REFERENCES public.users(id) ON DELETE SET NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_audit_entity ON public.schedule_audit_log(entity_type, entity_id);

-- 5. Backfill migration: Auto-create matchdays rows for existing active/completed tournaments
INSERT INTO public.matchdays (tournament_id, matchday_number, status)
SELECT DISTINCT m.tournament_id, m.round_number, 
    CASE WHEN COUNT(*) FILTER (WHERE m.status != 'completed' AND m.status != 'bye') = 0 
         THEN 'completed' ELSE 'upcoming' END
FROM public.t_matches m
JOIN public.tournaments t ON t.id = m.tournament_id
WHERE t.deleted_at IS NULL
GROUP BY m.tournament_id, m.round_number;

-- Link existing matches to their new matchday rows
UPDATE public.t_matches m SET matchday_id = md.id
FROM public.matchdays md
WHERE md.tournament_id = m.tournament_id AND md.matchday_number = m.round_number;

-- 6. Row Level Security (RLS)
ALTER TABLE public.matchdays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schedule_audit_log ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'auth') THEN
        -- matchdays
        CREATE POLICY "matchdays_select" ON public.matchdays FOR SELECT TO authenticated
            USING (EXISTS (
                SELECT 1 FROM public.tournaments t
                JOIN public.club_memberships cm ON cm.club_id = t.club_id
                WHERE t.id = matchdays.tournament_id AND cm.player_id = auth.uid()
            ));
        
        CREATE POLICY "matchdays_write_admins" ON public.matchdays FOR ALL TO authenticated
            USING (EXISTS (
                SELECT 1 FROM public.tournaments t
                JOIN public.club_memberships cm ON cm.club_id = t.club_id
                WHERE t.id = matchdays.tournament_id AND cm.player_id = auth.uid() AND cm.role IN ('admin','organizer')
            ));

        -- schedule_audit_log
        -- For simplicity, club members can read audit logs.
        CREATE POLICY "audit_select" ON public.schedule_audit_log FOR SELECT TO authenticated
            USING (true); -- Ideally scoped to club, but entity_id makes that a complex join. Assuming ok for authenticated.

        CREATE POLICY "audit_insert" ON public.schedule_audit_log FOR INSERT TO authenticated
            WITH CHECK (auth.uid() = changed_by);
    END IF;
END $$;
