-- Add player_1_score and player_2_score columns to T_Matches table
ALTER TABLE T_Matches ADD COLUMN IF NOT EXISTS player_1_score INT;
ALTER TABLE T_Matches ADD COLUMN IF NOT EXISTS player_2_score INT;
