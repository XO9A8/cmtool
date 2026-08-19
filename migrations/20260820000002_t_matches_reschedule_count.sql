-- Add reschedule_count to track the number of times a match has been rescheduled
ALTER TABLE T_Matches ADD COLUMN reschedule_count INT NOT NULL DEFAULT 0;
