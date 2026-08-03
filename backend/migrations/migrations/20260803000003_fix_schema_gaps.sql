-- Fix BUG 11: Add club_id to Elo_History (insert was already referencing it, column was missing)
ALTER TABLE Elo_History ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES Clubs(id) ON DELETE SET NULL;

-- Fix BUG 12: Add t_match_id to Match_Records (reverse FK link Match_Records → T_Matches)
ALTER TABLE Match_Records ADD COLUMN IF NOT EXISTS t_match_id UUID REFERENCES T_Matches(id) ON DELETE SET NULL;
