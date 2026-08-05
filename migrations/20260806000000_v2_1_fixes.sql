-- Drop the existing constraint that causes collisions in group knockout formats
ALTER TABLE T_Matches DROP CONSTRAINT IF EXISTS t_matches_unique_slot;

-- Drop partial indexes if they existed from previous attempts
DROP INDEX IF EXISTS t_matches_unique_knockout_slot;
DROP INDEX IF EXISTS t_matches_unique_group_slot;

-- For knockout matches (no group), match_number must be unique per round within the tournament
CREATE UNIQUE INDEX t_matches_unique_knockout_slot 
ON T_Matches (tournament_id, round_number, match_number) 
WHERE group_name IS NULL;

-- For group matches, match_number must be unique per group per round within the tournament
CREATE UNIQUE INDEX t_matches_unique_group_slot 
ON T_Matches (tournament_id, round_number, match_number, group_name) 
WHERE group_name IS NOT NULL;

-- Ensure a match record can only have one open dispute ticket at a time
CREATE UNIQUE INDEX IF NOT EXISTS match_disputes_unique_open 
ON Match_Disputes (match_record_id) 
WHERE status = 'open';
