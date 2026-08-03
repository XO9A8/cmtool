-- Fix BUG 1: Add idempotency guard to League_Standings to prevent double-counting
-- on re-confirmation of the same match.
ALTER TABLE League_Standings ADD COLUMN IF NOT EXISTS last_processed_match_id UUID;
