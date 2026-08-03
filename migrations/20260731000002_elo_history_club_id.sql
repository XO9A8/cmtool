-- 1. Add club_id to Elo_History
ALTER TABLE Elo_History ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES Clubs(id) ON DELETE CASCADE;

-- Update existing Elo_History records to infer club_id from Match_Records if they exist
UPDATE Elo_History e
SET club_id = m.club_id
FROM Match_Records m
WHERE e.match_record_id = m.id AND e.club_id IS NULL;

-- Create index for club-specific timeline queries
CREATE INDEX IF NOT EXISTS idx_elo_history_club ON Elo_History(club_id, recorded_at DESC);

-- 2. Remove 'swiss' from Tournaments format_type constraint
-- We need to check if there is an existing constraint, but for now we can just assume there wasn't a strict DB-level ENUM, or we add one if it doesn't exist.
-- Assuming `Tournaments` just has a `VARCHAR` check, we'll replace or add a check constraint.
ALTER TABLE Tournaments DROP CONSTRAINT IF EXISTS tournaments_format_type_check;

ALTER TABLE Tournaments ADD CONSTRAINT tournaments_format_type_check
CHECK (format_type IN ('knockout', 'round_robin', 'league'));
