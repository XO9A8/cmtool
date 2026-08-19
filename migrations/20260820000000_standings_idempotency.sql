-- =============================================================================
-- CMTool Database — League Standings Idempotency Migration
-- Migration: 20260820000000_standings_idempotency.sql
-- =============================================================================

ALTER TABLE public.league_standings ADD COLUMN IF NOT EXISTS processed_match_ids UUID[] DEFAULT '{}'::UUID[];

-- Backfill from last_processed_match_id if it exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema='public' AND table_name='league_standings' AND column_name='last_processed_match_id'
    ) THEN
        UPDATE public.league_standings 
        SET processed_match_ids = ARRAY[last_processed_match_id] 
        WHERE last_processed_match_id IS NOT NULL;

        ALTER TABLE public.league_standings DROP COLUMN last_processed_match_id;
    END IF;
END $$;
