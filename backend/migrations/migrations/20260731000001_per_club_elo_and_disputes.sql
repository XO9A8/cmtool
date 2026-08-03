-- 1. Add per-club Elo, Form rating, and Play Style to Club_Memberships
ALTER TABLE Club_Memberships ADD COLUMN IF NOT EXISTS skill_rating INT DEFAULT 1000;
ALTER TABLE Club_Memberships ADD COLUMN IF NOT EXISTS form_rating NUMERIC(5,2) DEFAULT 50.00;
ALTER TABLE Club_Memberships ADD COLUMN IF NOT EXISTS play_style VARCHAR(50) DEFAULT 'Unclassified';

-- 1b. Update Player_Profiles to only track global lifetime stats
ALTER TABLE Player_Profiles DROP COLUMN IF EXISTS skill_rating;
ALTER TABLE Player_Profiles DROP COLUMN IF EXISTS form_rating;
ALTER TABLE Player_Profiles DROP COLUMN IF EXISTS play_style;
ALTER TABLE Player_Profiles ADD COLUMN IF NOT EXISTS lifetime_matches INT DEFAULT 0;
ALTER TABLE Player_Profiles ADD COLUMN IF NOT EXISTS lifetime_wins INT DEFAULT 0;

-- 2. Enhance Match_Disputes with resolution fields & counter evidence
ALTER TABLE Match_Disputes ADD COLUMN IF NOT EXISTS counter_screenshot_url TEXT;
ALTER TABLE Match_Disputes ADD COLUMN IF NOT EXISTS resolved_by UUID REFERENCES Users(id) ON DELETE SET NULL;
ALTER TABLE Match_Disputes ADD COLUMN IF NOT EXISTS resolution_notes TEXT;
ALTER TABLE Match_Disputes ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;

-- 3. Add club_id to Match_Records
ALTER TABLE Match_Records ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES Clubs(id) ON DELETE CASCADE;

-- 4. Add composite deduplication & query index on Match_Records
CREATE INDEX IF NOT EXISTS idx_matches_composite ON Match_Records (player_id, opponent_id, created_at DESC);
