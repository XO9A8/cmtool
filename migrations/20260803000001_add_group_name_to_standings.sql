-- Add group_name to League_Standings and T_Matches tables
ALTER TABLE League_Standings ADD COLUMN IF NOT EXISTS group_name VARCHAR(50);
ALTER TABLE T_Matches ADD COLUMN IF NOT EXISTS group_name VARCHAR(50);
