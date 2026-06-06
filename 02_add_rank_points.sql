-- Add rank_points column for competitive matchmaking
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS rank_points INT DEFAULT 1000;

-- Ensure existing users have exactly 1000 RP to start
UPDATE profiles SET rank_points = 1000 WHERE rank_points IS NULL;
