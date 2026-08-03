-- 1. Clubs Table
CREATE TABLE IF NOT EXISTS Clubs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    invite_code VARCHAR(10) UNIQUE NOT NULL,
    owner_id UUID, -- Foreign key added below after Users table exists
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 2. Users Table
CREATE TABLE IF NOT EXISTS Users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Foreign key for Clubs owner
ALTER TABLE Clubs DROP CONSTRAINT IF EXISTS fk_owner;
ALTER TABLE Clubs ADD CONSTRAINT fk_owner FOREIGN KEY (owner_id) REFERENCES Users(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;

-- 2b. Club Memberships (Multi-Club Support)
CREATE TABLE IF NOT EXISTS Club_Memberships (
    player_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    club_id UUID REFERENCES Clubs(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'player', -- 'admin', 'organizer', 'player'
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (player_id, club_id)
);

-- 3. Player Profiles
CREATE TABLE IF NOT EXISTS Player_Profiles (
    user_id UUID PRIMARY KEY REFERENCES Users(id) ON DELETE CASCADE,
    skill_rating INT DEFAULT 1000,
    form_rating NUMERIC(5,2) DEFAULT 50.00,
    play_style VARCHAR(50) DEFAULT 'Unclassified',
    efootball_game_id VARCHAR(50),
    preferred_foot VARCHAR(10) DEFAULT 'RIGHT',
    jersey_number INT DEFAULT 10,
    system_device VARCHAR(100) DEFAULT 'REDMI NOTE 14 PRO+',
    facebook VARCHAR(255),
    blood_group VARCHAR(10) DEFAULT 'O+',
    district VARCHAR(100) DEFAULT 'DHAKA',
    date_of_birth DATE DEFAULT '2000-01-01',
    registrar_joined DATE DEFAULT '2026-07-26',
    contract_start DATE DEFAULT '2026-07-29',
    contract_end DATE DEFAULT '2027-01-25',
    facebook_link VARCHAR(100),
    email_node VARCHAR(150),
    phone_line VARCHAR(50),
    node_state VARCHAR(20) DEFAULT 'ACTIVE',
    auth_status VARCHAR(20) DEFAULT 'MEMBER',
    source_feed VARCHAR(100) DEFAULT 'CENTRAL FEDERATION',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Tournaments
CREATE TABLE IF NOT EXISTS Tournaments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID REFERENCES Clubs(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    format_type VARCHAR(20) NOT NULL, -- 'knockout', 'round_robin', 'swiss', 'league'
    status VARCHAR(20) DEFAULT 'draft', -- 'draft', 'active', 'completed'
    rules_config JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 5. Tournament Matches
CREATE TABLE IF NOT EXISTS T_Matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID REFERENCES Tournaments(id) ON DELETE CASCADE,
    player_1_id UUID REFERENCES Users(id),
    player_2_id UUID REFERENCES Users(id),
    round_number INT NOT NULL,
    status VARCHAR(20) DEFAULT 'scheduled', -- 'scheduled', 'completed', 'disputed'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Match Records
CREATE TABLE IF NOT EXISTS Match_Records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    opponent_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    partner_id UUID REFERENCES Users(id) ON DELETE SET NULL, -- for 2v2
    opponent_partner_id UUID REFERENCES Users(id) ON DELETE SET NULL, -- for 2v2
    t_match_id UUID REFERENCES T_Matches(id) ON DELETE SET NULL,
    match_type VARCHAR(20) NOT NULL DEFAULT 'friendly', -- 'friendly', 'league', 'tournament_final'
    result VARCHAR(10) NOT NULL, -- 'win', 'draw', 'loss'
    goals_for INT NOT NULL,
    goals_against INT NOT NULL,
    possession NUMERIC(4,1) NOT NULL,
    passes_completed INT NOT NULL,
    passes_attempted INT NOT NULL,
    shots_on_target INT NOT NULL,
    shots_total INT NOT NULL,
    interceptions INT NOT NULL,
    ocr_confidence NUMERIC(4,1) DEFAULT 100.0,
    screenshot_hash VARCHAR(64) UNIQUE NOT NULL,
    screenshot_url TEXT,
    verification_status VARCHAR(20) DEFAULT 'approved', -- 'pending', 'approved', 'disputed'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Link T_Matches to Match_Records
ALTER TABLE T_Matches DROP CONSTRAINT IF EXISTS fk_t_matches_match_record;
ALTER TABLE T_Matches ADD COLUMN IF NOT EXISTS match_record_id UUID REFERENCES Match_Records(id) ON DELETE SET NULL;

-- 7. Elo Rating History
CREATE TABLE IF NOT EXISTS Elo_History (
    id BIGSERIAL PRIMARY KEY,
    player_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    match_record_id UUID REFERENCES Match_Records(id) ON DELETE CASCADE,
    rating_before INT NOT NULL,
    rating_after INT NOT NULL,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. League Standings
CREATE TABLE IF NOT EXISTS League_Standings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID REFERENCES Tournaments(id) ON DELETE CASCADE,
    player_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    played INT DEFAULT 0,
    won INT DEFAULT 0,
    drawn INT DEFAULT 0,
    lost INT DEFAULT 0,
    goals_for INT DEFAULT 0,
    goals_against INT DEFAULT 0,
    goal_diff INT DEFAULT 0,
    points INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tournament_id, player_id)
);

-- 9. Squad Verifications
CREATE TABLE IF NOT EXISTS Squad_Verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    t_match_id UUID REFERENCES T_Matches(id) ON DELETE CASCADE,
    player_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    team_strength INT NOT NULL,
    screenshot_url TEXT NOT NULL,
    is_valid BOOLEAN DEFAULT TRUE,
    uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Match Disputes
CREATE TABLE IF NOT EXISTS Match_Disputes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_record_id UUID REFERENCES Match_Records(id) ON DELETE CASCADE,
    raised_by UUID REFERENCES Users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'open', -- 'open', 'resolved', 'dismissed'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. Seasons & Snapshots
CREATE TABLE IF NOT EXISTS Seasons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID REFERENCES Clubs(id),
    name VARCHAR(100) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS Season_Snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    season_id UUID REFERENCES Seasons(id),
    player_id UUID REFERENCES Users(id),
    final_skill_rating INT NOT NULL,
    final_form_rating NUMERIC(5,2),
    matches_played INT,
    win_rate NUMERIC(5,2)
);

-- 12. Badges System
CREATE TABLE IF NOT EXISTS Badges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url TEXT,
    criteria JSONB NOT NULL
);

CREATE TABLE IF NOT EXISTS Player_Badges (
    player_id UUID REFERENCES Users(id) ON DELETE CASCADE,
    badge_id UUID REFERENCES Badges(id),
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (player_id, badge_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_match_records_player ON Match_Records(player_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_elo_history_player ON Elo_History(player_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_league_standings_tournament ON League_Standings(tournament_id, points DESC);

-- Row Level Security (RLS)
ALTER TABLE Match_Records ENABLE ROW LEVEL SECURITY;
ALTER TABLE Tournaments ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'auth') THEN
        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Matches visible to club members') THEN
            CREATE POLICY "Matches visible to club members" ON Match_Records FOR SELECT
            USING (
              EXISTS (
                SELECT 1 FROM Club_Memberships cm1 
                JOIN Club_Memberships cm2 ON cm1.club_id = cm2.club_id
                WHERE cm1.player_id = Match_Records.player_id AND cm2.player_id = auth.uid()
              )
            );
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Users can insert their own matches') THEN
            CREATE POLICY "Users can insert their own matches" ON Match_Records FOR INSERT
            WITH CHECK (auth.uid() = player_id);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Admins manage tournaments') THEN
            CREATE POLICY "Admins manage tournaments" ON Tournaments FOR ALL
            USING (
              EXISTS (
                SELECT 1 FROM Club_Memberships 
                WHERE player_id = auth.uid() AND club_id = Tournaments.club_id AND role IN ('admin', 'organizer')
              )
            );
        END IF;
    END IF;
END $$;
