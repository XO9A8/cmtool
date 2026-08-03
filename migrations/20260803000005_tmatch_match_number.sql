-- Add match_number to T_Matches for knockout slot addressing (advance_knockout_winner needs it)
ALTER TABLE T_Matches ADD COLUMN IF NOT EXISTS match_number INT NOT NULL DEFAULT 1;
