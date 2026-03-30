-- ============================================================
-- Migration 002: browsing_sessions table + sync token
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Add sync_token to profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS sync_token UUID DEFAULT gen_random_uuid();

-- Create index for token lookup
CREATE INDEX IF NOT EXISTS idx_profiles_sync_token ON profiles(sync_token);

-- 2. Create browsing_sessions table
CREATE TABLE IF NOT EXISTS browsing_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  domain TEXT NOT NULL,
  label TEXT,
  category TEXT NOT NULL,
  title TEXT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  duration_seconds INT NOT NULL,
  source TEXT DEFAULT 'browser-extension',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_bs_user_start
  ON browsing_sessions(user_id, start_time);

CREATE INDEX IF NOT EXISTS idx_bs_user_category_start
  ON browsing_sessions(user_id, category, start_time);

-- 4. Unique constraint for deduplication
ALTER TABLE browsing_sessions
  ADD CONSTRAINT uq_bs_user_domain_start UNIQUE (user_id, domain, start_time);

-- 5. RLS
ALTER TABLE browsing_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own sessions"
  ON browsing_sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions"
  ON browsing_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own sessions"
  ON browsing_sessions FOR DELETE
  USING (auth.uid() = user_id);

-- 6. RPC: lookup user_id by sync_token (bypasses RLS for extension auth)
CREATE OR REPLACE FUNCTION get_user_id_by_sync_token(token UUID)
RETURNS UUID AS $$
  SELECT id FROM profiles WHERE sync_token = $1;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 7. RPC: insert session bypassing RLS (called by server with validated user_id)
CREATE OR REPLACE FUNCTION insert_browsing_session(
  p_user_id UUID,
  p_domain TEXT,
  p_label TEXT,
  p_category TEXT,
  p_title TEXT,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_duration_seconds INT,
  p_source TEXT DEFAULT 'browser-extension'
)
RETURNS UUID AS $$
  INSERT INTO browsing_sessions (user_id, domain, label, category, title, start_time, end_time, duration_seconds, source)
  VALUES (p_user_id, p_domain, p_label, p_category, p_title, p_start_time, p_end_time, p_duration_seconds, p_source)
  ON CONFLICT (user_id, domain, start_time) DO NOTHING
  RETURNING id;
$$ LANGUAGE sql SECURITY DEFINER;
