-- ============================================================
-- Callbreak Supabase Migration
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- 1. User profiles
-- Fallback migration for existing profiles
ALTER TABLE IF EXISTS profiles DROP COLUMN IF EXISTS is_premium_subscriber;
ALTER TABLE IF EXISTS profiles ADD COLUMN IF NOT EXISTS premium_until TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE,
  avatar_url TEXT,
  total_wins INT DEFAULT 0,
  total_games INT DEFAULT 0,
  total_score DOUBLE PRECISION DEFAULT 0,
  coin_balance INT DEFAULT 0,
  premium_until TIMESTAMPTZ,
  unlocked_skins TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Match results — one row per player per finished game
CREATE TABLE IF NOT EXISTS match_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  room_id TEXT NOT NULL,
  score DOUBLE PRECISION NOT NULL,
  rank INT NOT NULL,
  played_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Friendships between users
CREATE TABLE IF NOT EXISTS friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  addressee_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT CHECK (status IN ('pending', 'accepted', 'blocked', 'unfriended')) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(requester_id, addressee_id)
);

-- ── Auto-create profile on new sign-in ──────────────────────────────
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, avatar_url)
  VALUES (
    NEW.id,
    'pending_' || NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ── Row Level Security ─────────────────────────────────────────────────────
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

-- Profiles: anyone can read; only owner can update
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
CREATE POLICY "Profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Match results: anyone can read (public leaderboard); only service role can insert
DROP POLICY IF EXISTS "Match results are viewable by everyone" ON match_results;
CREATE POLICY "Match results are viewable by everyone" ON match_results FOR SELECT USING (true);

-- Friendships: users can see and manage their own
DROP POLICY IF EXISTS "Users can view their friendships" ON friendships;
CREATE POLICY "Users can view their friendships" ON friendships
  FOR SELECT USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
DROP POLICY IF EXISTS "Users can create friend requests" ON friendships;
CREATE POLICY "Users can create friend requests" ON friendships
  FOR INSERT WITH CHECK (auth.uid() = requester_id);
DROP POLICY IF EXISTS "Users can update their friendships" ON friendships;
CREATE POLICY "Users can update their friendships" ON friendships
  FOR UPDATE USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- ── Indexes for performance ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_match_results_user_id ON match_results(user_id);
CREATE INDEX IF NOT EXISTS idx_match_results_played_at ON match_results(played_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_total_wins ON profiles(total_wins DESC);
CREATE INDEX IF NOT EXISTS idx_friendships_requester ON friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON friendships(addressee_id);

-- 4. Match scorecards — full game history and round-by-round scores
CREATE TABLE IF NOT EXISTS match_scorecards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id TEXT NOT NULL,
  played_at TIMESTAMPTZ DEFAULT NOW(),
  -- JSONB array: [{ id, name, is_bot, total_score, rank }]
  participants JSONB NOT NULL,
  -- JSONB array: [{ "playerId": 10.0, "bot_1": 12.0 }, ...]
  round_scores JSONB NOT NULL
);

-- 5. Mapping table for user's game history
CREATE TABLE IF NOT EXISTS user_match_records (
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  match_id UUID REFERENCES match_scorecards(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, match_id)
);

-- ── Row Level Security for Scorecards ──────────────────────────────────────
ALTER TABLE match_scorecards ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_match_records ENABLE ROW LEVEL SECURITY;

-- Match scorecards: anyone can read; only service role can insert
DROP POLICY IF EXISTS "Match scorecards are viewable by everyone" ON match_scorecards;
CREATE POLICY "Match scorecards are viewable by everyone" ON match_scorecards FOR SELECT USING (true);

-- User match records: anyone can read; only service role can insert
DROP POLICY IF EXISTS "User match records are viewable by everyone" ON user_match_records;
CREATE POLICY "User match records are viewable by everyone" ON user_match_records FOR SELECT USING (true);

-- ── Indexes for performance ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_user_match_records_user_id ON user_match_records(user_id);

-- 6. Store Items
CREATE TABLE IF NOT EXISTS store_items (
  id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  name TEXT NOT NULL,
  price INT NOT NULL,
  preview_url TEXT
);

-- Seed initial store items
INSERT INTO store_items (id, category, name, price, preview_url) VALUES
('premium_1_week', 'subscription', 'Premium (1 Week)', 200, null),
('premium_1_month', 'subscription', 'Premium (1 Month)', 450, null),
('premium_1_year', 'subscription', 'Premium (1 Year)', 1000, null),
('red_felt', 'felt', 'Red Felt', 500, 'assets/felts/red.png'),
('blue_felt', 'felt', 'Blue Felt', 500, 'assets/felts/blue.png'),
('neon_cards', 'cards', 'Neon Cards', 800, 'assets/cards/neon.png'),
('gold_cards', 'cards', 'Gold Cards', 1000, 'assets/cards/gold.png')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE store_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Store items are viewable by everyone" ON store_items;
CREATE POLICY "Store items are viewable by everyone" ON store_items FOR SELECT USING (true);
