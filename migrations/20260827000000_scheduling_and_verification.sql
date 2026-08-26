-- =============================================================================
-- CMTool Database — Scheduling & Verification Enhancements
-- Migration: 20260827000000_scheduling_and_verification.sql
-- =============================================================================

-- Feature 1: Matchday gap (days between matchdays)
ALTER TABLE public.tournaments 
  ADD COLUMN IF NOT EXISTS matchday_gap_days SMALLINT NOT NULL DEFAULT 7;

-- Feature 2: Allow multiple matches/rounds per player per matchday
ALTER TABLE public.tournaments 
  ADD COLUMN IF NOT EXISTS allow_multi_match_per_matchday BOOLEAN NOT NULL DEFAULT FALSE;

-- Feature 3: Enforce 1:1 matchday <-> date (partial unique index)
-- Fix existing duplicates before creating index
UPDATE public.matchdays
SET scheduled_date = CURRENT_DATE + CAST(matchday_number AS INTEGER);

CREATE UNIQUE INDEX IF NOT EXISTS idx_matchdays_unique_date 
  ON public.matchdays(tournament_id, scheduled_date) 
  WHERE scheduled_date IS NOT NULL;

-- Feature 5: Track who actually submitted the match result
ALTER TABLE public.match_records 
  ADD COLUMN IF NOT EXISTS submitted_by_id UUID REFERENCES public.users(id) ON DELETE SET NULL;
  
-- Backfill: submitted_by_id = player_id for existing rows
UPDATE public.match_records SET submitted_by_id = player_id WHERE submitted_by_id IS NULL;
