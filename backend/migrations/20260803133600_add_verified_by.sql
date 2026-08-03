ALTER TABLE Match_Records ADD COLUMN verified_by_id UUID REFERENCES Users(id);
