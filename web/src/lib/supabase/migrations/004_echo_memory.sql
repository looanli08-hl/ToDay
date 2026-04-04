-- ============================================================
-- Migration 004: echo_memory table for Echo AI companion
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Create echo_memory table
CREATE TABLE IF NOT EXISTS echo_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  memory_type TEXT NOT NULL CHECK (memory_type IN ('interest', 'personality', 'pattern', 'event', 'note')),
  content JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_echo_memory_user ON echo_memory(user_id, memory_type);
CREATE INDEX IF NOT EXISTS idx_echo_memory_updated ON echo_memory(user_id, updated_at DESC);

-- 3. RLS
ALTER TABLE echo_memory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own memory"
  ON echo_memory FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own memory"
  ON echo_memory FOR DELETE
  USING (auth.uid() = user_id);

-- 4. RPC: insert memory bypassing RLS (called by server with validated user_id)
CREATE OR REPLACE FUNCTION insert_echo_memory(
  p_user_id UUID,
  p_memory_type TEXT,
  p_content JSONB
) RETURNS UUID AS $$
DECLARE
  new_id UUID;
BEGIN
  INSERT INTO echo_memory (user_id, memory_type, content)
  VALUES (p_user_id, p_memory_type, p_content)
  RETURNING id INTO new_id;
  RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
