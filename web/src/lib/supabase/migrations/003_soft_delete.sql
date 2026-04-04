-- ============================================================
-- Migration 003: Soft delete support for GDPR compliance
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Add deleted_at columns
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

ALTER TABLE data_points
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

ALTER TABLE browsing_sessions
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

ALTER TABLE mood_records
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

-- 2. Create indexes for soft delete filtering
CREATE INDEX IF NOT EXISTS idx_data_points_deleted
  ON data_points(deleted_at) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_browsing_sessions_deleted
  ON browsing_sessions(deleted_at) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_mood_records_deleted
  ON mood_records(deleted_at) WHERE deleted_at IS NULL;

-- 3. Update RLS policies to exclude soft-deleted rows

-- data_points
DROP POLICY IF EXISTS "Users can manage own data" ON data_points;
CREATE POLICY "Users can manage own data" ON data_points
  FOR ALL USING (auth.uid() = user_id AND deleted_at IS NULL);

-- browsing_sessions
DROP POLICY IF EXISTS "Users can view own sessions" ON browsing_sessions;
CREATE POLICY "Users can view own sessions" ON browsing_sessions
  FOR SELECT USING (auth.uid() = user_id AND deleted_at IS NULL);

DROP POLICY IF EXISTS "Users can insert own sessions" ON browsing_sessions;
CREATE POLICY "Users can insert own sessions" ON browsing_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own sessions" ON browsing_sessions;
CREATE POLICY "Users can delete own sessions" ON browsing_sessions
  FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own sessions" ON browsing_sessions;
CREATE POLICY "Users can update own sessions" ON browsing_sessions
  FOR UPDATE USING (auth.uid() = user_id);

-- mood_records
DROP POLICY IF EXISTS "Users can manage own moods" ON mood_records;
CREATE POLICY "Users can manage own moods" ON mood_records
  FOR ALL USING (auth.uid() = user_id AND deleted_at IS NULL);

-- 4. RPC: soft-delete user data
CREATE OR REPLACE FUNCTION soft_delete_user_data(p_user_id UUID)
RETURNS void AS $$
  UPDATE data_points SET deleted_at = NOW() WHERE user_id = p_user_id AND deleted_at IS NULL;
  UPDATE browsing_sessions SET deleted_at = NOW() WHERE user_id = p_user_id AND deleted_at IS NULL;
  UPDATE mood_records SET deleted_at = NOW() WHERE user_id = p_user_id AND deleted_at IS NULL;
$$ LANGUAGE sql SECURITY DEFINER;

-- 5. RPC: soft-delete user account
CREATE OR REPLACE FUNCTION soft_delete_user_account(p_user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE profiles SET deleted_at = NOW() WHERE id = p_user_id AND deleted_at IS NULL;
  PERFORM soft_delete_user_data(p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
