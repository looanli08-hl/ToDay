# Screen Time Real Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace mock data on the screen time page with real browser extension data, using normalized relational storage and server-side SQL aggregation.

**Architecture:** New `browsing_sessions` Supabase table (1 row per session), two new API routes (`POST /api/sessions` for ingestion, `GET /api/screen-time` for aggregation), browser extension incremental sync with sync-token auth, and frontend wired to real data.

**Tech Stack:** Next.js App Router, Supabase (PostgreSQL + RLS), Chrome Extension Manifest V3

---

## File Structure

**New files:**
- `web/src/lib/supabase/migrations/002_browsing_sessions.sql` — DDL for new table, indexes, RLS, sync token, RPC function
- `web/src/app/api/sessions/route.ts` — POST endpoint: validate sync token, insert sessions
- `web/src/app/api/screen-time/route.ts` — GET endpoint: SQL aggregation queries

**Modified files:**
- `web/src/app/dashboard/screen-time/page.tsx` — replace mock with real data fetching
- `web/src/app/dashboard/settings/page.tsx` — add sync token display section
- `extension/src/background.js` — incremental sync, configurable URL, auth header
- `extension/src/popup.html` — add settings section with token + URL inputs
- `extension/src/popup.js` — add settings save/load logic
- `extension/manifest.json` — add Vercel URL to host_permissions

---

### Task 1: Database Migration SQL

**Files:**
- Create: `web/src/lib/supabase/migrations/002_browsing_sessions.sql`

This SQL must be run manually in Supabase SQL Editor after writing the file.

- [ ] **Step 1: Write the migration SQL**

Create `web/src/lib/supabase/migrations/002_browsing_sessions.sql`:

```sql
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
```

- [ ] **Step 2: Run migration in Supabase SQL Editor**

1. Open https://supabase.com/dashboard → ToDay project → SQL Editor
2. Paste the full SQL from `002_browsing_sessions.sql`
3. Click "Run"
4. Verify: run `SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'browsing_sessions';` — should show 11 columns
5. Verify: run `SELECT sync_token FROM profiles LIMIT 1;` — should return a UUID

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/lib/supabase/migrations/002_browsing_sessions.sql
git commit -m "feat: add browsing_sessions table + sync token migration SQL"
```

---

### Task 2: POST /api/sessions Endpoint

**Files:**
- Create: `web/src/app/api/sessions/route.ts`

- [ ] **Step 1: Write the sessions API route**

Create `web/src/app/api/sessions/route.ts`:

```typescript
import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";

interface SessionPayload {
  domain: string;
  label?: string;
  category: string;
  title?: string;
  startTime: number; // epoch ms
  endTime: number;   // epoch ms
  duration: number;  // seconds
}

export async function POST(req: NextRequest) {
  try {
    // 1. Extract sync token from Authorization header
    const authHeader = req.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return Response.json(
        { error: "Missing Authorization header" },
        { status: 401 }
      );
    }
    const syncToken = authHeader.slice(7).trim();

    // 2. Parse body
    const body = await req.json();
    const sessions: SessionPayload[] = body.sessions;

    if (!Array.isArray(sessions) || sessions.length === 0) {
      return Response.json(
        { error: "sessions must be a non-empty array" },
        { status: 400 }
      );
    }

    // 3. Look up user_id by sync token
    const supabase = await createServerSupabaseClient();
    const { data: userId, error: rpcError } = await supabase.rpc(
      "get_user_id_by_sync_token",
      { token: syncToken }
    );

    if (rpcError || !userId) {
      return Response.json(
        { error: "Invalid sync token" },
        { status: 401 }
      );
    }

    // 4. Insert sessions via RPC (bypasses RLS)
    let inserted = 0;
    let duplicates = 0;

    for (const session of sessions) {
      if (!session.domain || !session.category || !session.startTime || !session.endTime) {
        duplicates++;
        continue;
      }

      const { data } = await supabase.rpc("insert_browsing_session", {
        p_user_id: userId,
        p_domain: session.domain,
        p_label: session.label || null,
        p_category: session.category,
        p_title: session.title || null,
        p_start_time: new Date(session.startTime).toISOString(),
        p_end_time: new Date(session.endTime).toISOString(),
        p_duration_seconds: session.duration,
        p_source: "browser-extension",
      });

      if (data) {
        inserted++;
      } else {
        duplicates++;
      }
    }

    return Response.json({ inserted, duplicates });
  } catch {
    return Response.json({ error: "Invalid request" }, { status: 400 });
  }
}
```

- [ ] **Step 2: Verify with curl (after running migration)**

Start the dev server if not running, then test:

```bash
# Test missing auth
curl -s -X POST http://localhost:3001/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"sessions":[]}' | jq .
# Expected: {"error":"Missing Authorization header"}

# Test invalid token
curl -s -X POST http://localhost:3001/api/sessions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 00000000-0000-0000-0000-000000000000" \
  -d '{"sessions":[{"domain":"test.com","category":"其他","startTime":1711800000000,"endTime":1711800600000,"duration":600}]}' | jq .
# Expected: {"error":"Invalid sync token"}
```

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/api/sessions/route.ts
git commit -m "feat: add POST /api/sessions endpoint with sync token auth"
```

---

### Task 3: GET /api/screen-time Endpoint

**Files:**
- Create: `web/src/app/api/screen-time/route.ts`

- [ ] **Step 1: Write the screen-time aggregation API route**

Create `web/src/app/api/screen-time/route.ts`:

```typescript
import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";

const DAY_NAMES = ["日", "一", "二", "三", "四", "五", "六"];

function getDateRange(dateStr: string) {
  const start = `${dateStr}T00:00:00`;
  const end = `${dateStr}T23:59:59.999`;
  return { start, end };
}

function emptyResponse() {
  return {
    today: {
      totalMinutes: 0,
      categories: [],
      topSites: [],
      hourly: new Array(24).fill(0),
    },
    yesterday: { totalMinutes: 0 },
    weekly: [],
  };
}

export async function GET(req: NextRequest) {
  try {
    const supabase = await createServerSupabaseClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return Response.json({ error: "Not authenticated" }, { status: 401 });
    }

    const { searchParams } = new URL(req.url);
    const today =
      searchParams.get("date") ||
      new Date().toISOString().split("T")[0];
    const tz = searchParams.get("tz") || "Asia/Shanghai";

    const todayRange = getDateRange(today);

    // Yesterday date
    const yesterdayDate = new Date(today);
    yesterdayDate.setDate(yesterdayDate.getDate() - 1);
    const yesterdayStr = yesterdayDate.toISOString().split("T")[0];
    const yesterdayRange = getDateRange(yesterdayStr);

    // --- Query 1: Today's total ---
    const { data: totalData } = await supabase
      .from("browsing_sessions")
      .select("duration_seconds")
      .eq("user_id", user.id)
      .gte("start_time", todayRange.start)
      .lte("start_time", todayRange.end);

    const totalMinutes = totalData
      ? Math.round(
          totalData.reduce((sum, r) => sum + r.duration_seconds, 0) / 60
        )
      : 0;

    // --- Query 2: Categories ---
    const { data: catRows } = await supabase
      .from("browsing_sessions")
      .select("category, duration_seconds")
      .eq("user_id", user.id)
      .gte("start_time", todayRange.start)
      .lte("start_time", todayRange.end);

    const catMap = new Map<string, number>();
    for (const row of catRows || []) {
      catMap.set(
        row.category,
        (catMap.get(row.category) || 0) + row.duration_seconds
      );
    }
    const categories = Array.from(catMap.entries())
      .map(([name, seconds]) => ({ name, minutes: Math.round(seconds / 60) }))
      .sort((a, b) => b.minutes - a.minutes);

    // --- Query 3: Top Sites ---
    const { data: siteRows } = await supabase
      .from("browsing_sessions")
      .select("domain, title, duration_seconds")
      .eq("user_id", user.id)
      .gte("start_time", todayRange.start)
      .lte("start_time", todayRange.end);

    const siteMap = new Map<string, { title: string; seconds: number }>();
    for (const row of siteRows || []) {
      const existing = siteMap.get(row.domain);
      if (existing) {
        existing.seconds += row.duration_seconds;
        if (row.title) existing.title = row.title;
      } else {
        siteMap.set(row.domain, {
          title: row.title || row.domain,
          seconds: row.duration_seconds,
        });
      }
    }
    const topSites = Array.from(siteMap.entries())
      .map(([domain, { title, seconds }]) => ({
        domain,
        title,
        minutes: Math.round(seconds / 60),
      }))
      .sort((a, b) => b.minutes - a.minutes)
      .slice(0, 10);

    // --- Query 4: Hourly distribution ---
    const { data: hourlyRows } = await supabase
      .from("browsing_sessions")
      .select("start_time, duration_seconds")
      .eq("user_id", user.id)
      .gte("start_time", todayRange.start)
      .lte("start_time", todayRange.end);

    const hourly = new Array(24).fill(0);
    for (const row of hourlyRows || []) {
      const hour = new Date(row.start_time).getHours();
      hourly[hour] += row.duration_seconds / 60;
    }
    const hourlyRounded = hourly.map((v: number) => Math.round(v));

    // --- Query 5: Yesterday total ---
    const { data: yesterdayData } = await supabase
      .from("browsing_sessions")
      .select("duration_seconds")
      .eq("user_id", user.id)
      .gte("start_time", yesterdayRange.start)
      .lte("start_time", yesterdayRange.end);

    const yesterdayMinutes = yesterdayData
      ? Math.round(
          yesterdayData.reduce((sum, r) => sum + r.duration_seconds, 0) / 60
        )
      : 0;

    // --- Query 6: Weekly (7 days) ---
    const weeklyStart = new Date(today);
    weeklyStart.setDate(weeklyStart.getDate() - 6);
    const weeklyStartStr = weeklyStart.toISOString().split("T")[0];

    const { data: weeklyRows } = await supabase
      .from("browsing_sessions")
      .select("start_time, duration_seconds")
      .eq("user_id", user.id)
      .gte("start_time", `${weeklyStartStr}T00:00:00`)
      .lte("start_time", todayRange.end);

    const weeklyMap = new Map<string, number>();
    for (const row of weeklyRows || []) {
      const dateKey = row.start_time.split("T")[0];
      weeklyMap.set(dateKey, (weeklyMap.get(dateKey) || 0) + row.duration_seconds);
    }

    const weekly = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date(today);
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split("T")[0];
      const dayOfWeek = d.getDay();
      weekly.push({
        day: DAY_NAMES[dayOfWeek],
        date: dateStr,
        minutes: Math.round((weeklyMap.get(dateStr) || 0) / 60),
      });
    }

    return Response.json({
      today: {
        totalMinutes,
        categories,
        topSites,
        hourly: hourlyRounded,
      },
      yesterday: { totalMinutes: yesterdayMinutes },
      weekly,
    });
  } catch (err) {
    console.error("[screen-time] Error:", err);
    return Response.json(emptyResponse());
  }
}
```

- [ ] **Step 2: Verify with curl**

```bash
# Requires being logged in (cookie-based auth)
# Open dashboard in browser first, then test the API:
curl -s http://localhost:3001/api/screen-time | jq .
# Expected: JSON with today/yesterday/weekly structure (likely zeros if no data yet)
```

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/api/screen-time/route.ts
git commit -m "feat: add GET /api/screen-time with SQL aggregation"
```

---

### Task 4: Settings Page — Sync Token Display

**Files:**
- Modify: `web/src/app/dashboard/settings/page.tsx`

- [ ] **Step 1: Add sync token state and fetch logic**

In `web/src/app/dashboard/settings/page.tsx`, add after the existing `useState` declarations (around line 35):

```typescript
const [syncToken, setSyncToken] = useState<string | null>(null);
const [tokenCopied, setTokenCopied] = useState(false);
```

In the existing `useEffect` (around line 39), after `setDisplayName(...)`, add the sync token fetch:

```typescript
        // Fetch sync token
        supabase
          .from("profiles")
          .select("sync_token")
          .eq("id", user.id)
          .single()
          .then(({ data }) => {
            if (data?.sync_token) {
              setSyncToken(data.sync_token);
            }
          });
```

Add the `Copy` icon to the imports (line 8 area):

```typescript
import {
  User,
  Blocks,
  Bot,
  Shield,
  AlertTriangle,
  Smartphone,
  Globe,
  LogOut,
  Copy,
  Check,
} from "lucide-react";
```

- [ ] **Step 2: Add sync token UI section**

In the "数据源" card section, after the "浏览器扩展" row and before the "手机 App" row (around line 142), add:

```tsx
          {syncToken && (
            <div className="py-3 border-b border-border/30">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-foreground">同步令牌</p>
                  <p className="text-xs text-muted-foreground">
                    在浏览器扩展中输入此令牌以同步数据
                  </p>
                </div>
                <button
                  onClick={() => {
                    navigator.clipboard.writeText(syncToken);
                    setTokenCopied(true);
                    setTimeout(() => setTokenCopied(false), 2000);
                  }}
                  className="flex items-center gap-2 border border-border/50 text-muted-foreground rounded-full px-4 py-2 text-sm hover:text-foreground hover:border-border transition-colors"
                >
                  {tokenCopied ? (
                    <>
                      <Check className="h-3.5 w-3.5" strokeWidth={1.5} />
                      已复制
                    </>
                  ) : (
                    <>
                      <Copy className="h-3.5 w-3.5" strokeWidth={1.5} />
                      复制
                    </>
                  )}
                </button>
              </div>
              <code className="block mt-2 text-xs text-muted-foreground bg-muted/50 rounded-lg px-3 py-2 font-mono break-all select-all">
                {syncToken}
              </code>
            </div>
          )}
```

- [ ] **Step 3: Verify in browser**

1. Open http://localhost:3001/dashboard/settings
2. Log in if needed
3. The "数据源" section should show a "同步令牌" row with a UUID and a "复制" button
4. Click "复制" — should show "已复制" briefly

- [ ] **Step 4: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/dashboard/settings/page.tsx
git commit -m "feat: display sync token in settings for extension auth"
```

---

### Task 5: Screen Time Page — Real Data

**Files:**
- Modify: `web/src/app/dashboard/screen-time/page.tsx`

- [ ] **Step 1: Rewrite screen-time page with real data fetching**

Replace the entire contents of `web/src/app/dashboard/screen-time/page.tsx`:

```tsx
"use client";

import { useEffect, useState } from "react";
import { Card } from "@/components/ui/card";
import {
  Layers,
  ArrowDown,
  ArrowUp,
  Clock,
  Globe,
  BarChart3,
  MonitorSmartphone,
} from "lucide-react";

// --- Types ---

interface ScreenTimeData {
  today: {
    totalMinutes: number;
    categories: { name: string; minutes: number }[];
    topSites: { domain: string; title: string; minutes: number }[];
    hourly: number[];
  };
  yesterday: { totalMinutes: number };
  weekly: { day: string; date: string; minutes: number }[];
}

// --- Helpers ---

function formatDuration(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m}m`;
  return `${h}h ${m}m`;
}

const CATEGORY_COLORS: Record<string, string> = {
  "效率": "bg-primary/70",
  "娱乐": "bg-primary/55",
  "社交": "bg-primary/45",
  "通讯": "bg-primary/40",
  "学习": "bg-primary/35",
  "购物": "bg-primary/30",
  "搜索": "bg-primary/25",
  "AI工具": "bg-primary/20",
  "其他": "bg-primary/15",
};

// --- Component ---

export default function ScreenTimePage() {
  const [data, setData] = useState<ScreenTimeData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const today = new Date().toISOString().split("T")[0];
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;

    fetch(`/api/screen-time?date=${today}&tz=${tz}`)
      .then((res) => res.json())
      .then((json) => {
        setData(json);
        setLoading(false);
      })
      .catch(() => {
        setLoading(false);
      });
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen">
        <div className="px-12 pt-12 pb-10">
          <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
            屏幕时间
          </h1>
          <p className="text-base text-muted-foreground mt-2">
            了解你的数字生活习惯
          </p>
        </div>
        <div className="px-12 pb-12 space-y-8">
          {[1, 2, 3].map((i) => (
            <Card
              key={i}
              className="border border-border/40 bg-card rounded-xl p-6 h-40 animate-pulse"
            >
              <div className="h-4 w-32 bg-muted rounded mb-4" />
              <div className="h-8 w-24 bg-muted rounded" />
            </Card>
          ))}
        </div>
      </div>
    );
  }

  // Empty state
  if (!data || data.today.totalMinutes === 0) {
    return (
      <div className="min-h-screen">
        <div className="px-12 pt-12 pb-10">
          <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
            屏幕时间
          </h1>
          <p className="text-base text-muted-foreground mt-2">
            了解你的数字生活习惯
          </p>
        </div>
        <div className="px-12 pb-12">
          <Card className="border border-border/40 bg-card rounded-xl p-12 text-center">
            <MonitorSmartphone
              className="h-10 w-10 text-muted-foreground/40 mx-auto mb-4"
              strokeWidth={1}
            />
            <p className="text-foreground font-display text-lg">
              还没有浏览数据
            </p>
            <p className="text-sm text-muted-foreground mt-2">
              安装浏览器扩展并配置同步令牌，开始记录你的屏幕时间
            </p>
          </Card>
        </div>
      </div>
    );
  }

  const { today, yesterday, weekly } = data;
  const diff = yesterday.totalMinutes - today.totalMinutes;
  const diffPercent =
    yesterday.totalMinutes > 0
      ? Math.round((Math.abs(diff) / yesterday.totalMinutes) * 100)
      : 0;
  const isLess = diff > 0;

  const maxCategory = Math.max(...today.categories.map((c) => c.minutes), 1);
  const maxHourly = Math.max(...today.hourly, 1);
  const maxWeekly = Math.max(...weekly.map((d) => d.minutes), 1);

  return (
    <div className="min-h-screen">
      {/* Header */}
      <div className="px-12 pt-12 pb-10">
        <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
          屏幕时间
        </h1>
        <p className="text-base text-muted-foreground mt-2">
          了解你的数字生活习惯
        </p>
      </div>

      <div className="px-12 pb-12 space-y-8">
        {/* Today's Summary */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Clock className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">今日总览</h2>
          </div>
          <div className="flex items-end gap-4">
            <span className="font-display text-4xl font-normal text-foreground">
              {formatDuration(today.totalMinutes)}
            </span>
            {yesterday.totalMinutes > 0 && (
              <div className="flex items-center gap-1 pb-1.5">
                {isLess ? (
                  <ArrowDown className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                ) : (
                  <ArrowUp className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                )}
                <span className="text-sm text-muted-foreground">
                  比昨天{isLess ? "少" : "多"} {diffPercent}%
                </span>
              </div>
            )}
          </div>
        </Card>

        {/* Two-column layout */}
        <div className="grid gap-4 xl:grid-cols-2">
          {/* Category Breakdown */}
          <Card className="border border-border/40 bg-card rounded-xl p-6">
            <div className="flex items-center gap-2 mb-6">
              <Layers className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
              <h2 className="font-display text-lg text-foreground">分类用时</h2>
            </div>
            <div className="space-y-4">
              {today.categories.map((cat) => (
                <div key={cat.name}>
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-sm text-foreground">{cat.name}</span>
                    <span className="text-xs text-muted-foreground">
                      {formatDuration(cat.minutes)}
                    </span>
                  </div>
                  <div className="h-2 w-full rounded-full bg-muted">
                    <div
                      className={`h-full rounded-full ${CATEGORY_COLORS[cat.name] || "bg-primary/15"} transition-all duration-500`}
                      style={{
                        width: `${(cat.minutes / maxCategory) * 100}%`,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </Card>

          {/* Top Sites */}
          <Card className="border border-border/40 bg-card rounded-xl p-6">
            <div className="flex items-center gap-2 mb-6">
              <Globe className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
              <h2 className="font-display text-lg text-foreground">常用站点</h2>
            </div>
            <div className="space-y-0">
              {today.topSites.map((site, i) => (
                <div
                  key={site.domain}
                  className="flex items-center gap-3 py-3 border-b border-border/40 last:border-0"
                >
                  <span className="text-xs text-muted-foreground w-5 text-right">
                    {i + 1}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-foreground truncate">
                      {site.domain}
                    </p>
                    <p className="text-[11px] text-muted-foreground truncate">
                      {site.title}
                    </p>
                  </div>
                  <span className="text-xs text-muted-foreground whitespace-nowrap">
                    {formatDuration(site.minutes)}
                  </span>
                </div>
              ))}
            </div>
          </Card>
        </div>

        {/* Hourly Distribution */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-6">
            <BarChart3 className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">每小时分布</h2>
          </div>
          <div className="flex items-end gap-1 h-32">
            {today.hourly.map((val, i) => (
              <div
                key={i}
                className="flex flex-col items-center flex-1 gap-1.5 group"
              >
                <div className="w-full flex flex-col items-center justify-end h-24">
                  <div
                    className="w-full rounded-lg bg-primary/70 transition-all duration-500 min-h-[2px]"
                    style={{
                      height:
                        maxHourly > 0
                          ? `${Math.max((val / maxHourly) * 100, val > 0 ? 4 : 0)}%`
                          : "0%",
                    }}
                  />
                </div>
                {i % 3 === 0 ? (
                  <span className="text-[11px] text-muted-foreground">
                    {i.toString().padStart(2, "0")}
                  </span>
                ) : (
                  <span className="text-[11px] text-transparent">00</span>
                )}
              </div>
            ))}
          </div>
        </Card>

        {/* Weekly Trend */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-6">
            <BarChart3 className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">本周趋势</h2>
          </div>
          <div className="flex items-end justify-between gap-3 h-36">
            {weekly.map((d) => (
              <div
                key={d.date}
                className="flex flex-col items-center gap-2 flex-1"
              >
                <span className="text-xs text-muted-foreground">
                  {d.minutes > 0 ? formatDuration(d.minutes) : "—"}
                </span>
                <div className="w-full flex flex-col items-center justify-end h-24">
                  <div
                    className="w-full rounded-lg bg-primary/70 transition-all duration-500"
                    style={{
                      height:
                        d.minutes > 0
                          ? `${(d.minutes / maxWeekly) * 100}%`
                          : "2px",
                    }}
                  />
                </div>
                <span className="text-[11px] text-muted-foreground">
                  {d.day}
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Verify in browser**

1. Open http://localhost:3001/dashboard/screen-time
2. If no data: should show empty state with "还没有浏览数据" message
3. If there's data (after extension sync): should show real stats

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/dashboard/screen-time/page.tsx
git commit -m "feat: wire screen time page to real data from /api/screen-time"
```

---

### Task 6: Extension — Incremental Sync with Auth

**Files:**
- Modify: `extension/src/background.js`
- Modify: `extension/manifest.json`

- [ ] **Step 1: Update manifest.json host_permissions**

Replace the `host_permissions` in `extension/manifest.json`:

```json
  "host_permissions": [
    "http://localhost:3001/*",
    "https://to-day-ten.vercel.app/*"
  ],
```

- [ ] **Step 2: Rewrite background.js sync logic**

Replace the entire contents of `extension/src/background.js`:

```javascript
import { categorize } from "./categories.js";

// ─── Configuration ───

const HEARTBEAT_INTERVAL = 10; // seconds
const SYNC_INTERVAL = 1; // minutes
const IDLE_THRESHOLD = 120; // seconds
const DEFAULT_API_BASE = "https://to-day-ten.vercel.app";

// ─── State Management ───

async function getState() {
  const result = await chrome.storage.local.get([
    "currentSession",
    "sessions",
    "lastSync",
    "isIdle",
    "trackingEnabled",
    "lastSyncedCount",
    "syncToken",
    "apiBaseUrl",
  ]);
  return {
    currentSession: result.currentSession || null,
    sessions: result.sessions || {},
    lastSync: result.lastSync || null,
    isIdle: result.isIdle || false,
    trackingEnabled: result.trackingEnabled !== false,
    lastSyncedCount: result.lastSyncedCount || {},
    syncToken: result.syncToken || null,
    apiBaseUrl: result.apiBaseUrl || DEFAULT_API_BASE,
  };
}

async function saveState(updates) {
  await chrome.storage.local.set(updates);
}

// ─── Idle Detection ───

chrome.idle.setDetectionInterval(IDLE_THRESHOLD);

chrome.idle.onStateChanged.addListener(async (state) => {
  if (state === "idle" || state === "locked") {
    await closeCurrentSession("idle");
    await saveState({ isIdle: true });
    console.log("[ToDay] User idle — tracking paused");
  } else if (state === "active") {
    await saveState({ isIdle: false });
    heartbeat();
    console.log("[ToDay] User active — tracking resumed");
  }
});

// ─── Window Focus Detection ───

chrome.windows.onFocusChanged.addListener(async (windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE) {
    await closeCurrentSession("blur");
  } else {
    heartbeat();
  }
});

// ─── Session-Based Tracking ───

async function heartbeat() {
  try {
    const state = await getState();

    if (!state.trackingEnabled || state.isIdle) return;

    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    if (
      !tab ||
      !tab.url ||
      tab.url.startsWith("chrome://") ||
      tab.url.startsWith("chrome-extension://") ||
      tab.url.startsWith("about:") ||
      tab.url.startsWith("edge://")
    ) {
      await closeCurrentSession("internal");
      return;
    }

    if (tab.incognito) {
      await closeCurrentSession("incognito");
      return;
    }

    const url = tab.url;
    const title = tab.title || "";
    const domain = new URL(url).hostname.replace(/^www\./, "");
    const { category, label } = categorize(url);
    const now = Date.now();
    const todayKey = new Date().toISOString().split("T")[0];

    if (state.currentSession && state.currentSession.domain === domain) {
      const gap = now - state.currentSession.endTime;
      if (gap > 5 * 60 * 1000) {
        await closeCurrentSession("stale");
        await startNewSession({ domain, label, category, title, now, todayKey, state });
      } else {
        state.currentSession.endTime = now;
        if (title && title !== state.currentSession.title) {
          state.currentSession.title = title;
        }
        await saveState({ currentSession: state.currentSession });
      }
      return;
    }

    await closeCurrentSession("switch");
    await startNewSession({ domain, label, category, title, now, todayKey, state });
  } catch (e) {
    console.error("[ToDay] Heartbeat error:", e);
  }
}

async function startNewSession({ domain, label, category, title, now }) {
  const newSession = {
    domain,
    label,
    category,
    title,
    startTime: now,
    endTime: now,
  };

  await saveState({ currentSession: newSession });
}

async function closeCurrentSession(reason) {
  const state = await getState();
  if (!state.currentSession) return;

  const todayKey = new Date(state.currentSession.startTime).toISOString().split("T")[0];
  const todaySessions = state.sessions[todayKey] || [];
  const duration = Math.round((state.currentSession.endTime - state.currentSession.startTime) / 1000);

  if (duration >= 5) {
    todaySessions.push({
      domain: state.currentSession.domain,
      label: state.currentSession.label,
      category: state.currentSession.category,
      title: state.currentSession.title,
      startTime: state.currentSession.startTime,
      endTime: state.currentSession.endTime,
      duration,
    });
  }

  await saveState({
    currentSession: null,
    sessions: { ...state.sessions, [todayKey]: todaySessions },
  });
}

// ─── Incremental Data Sync ───

async function syncToServer() {
  try {
    const state = await getState();

    // Skip if no sync token configured
    if (!state.syncToken) {
      console.log("[ToDay] No sync token — skipping server sync");
      return;
    }

    const todayKey = new Date().toISOString().split("T")[0];
    const todaySessions = state.sessions[todayKey] || [];

    // Include current active session
    const allSessions = [...todaySessions];
    if (state.currentSession) {
      const now = Date.now();
      const duration = Math.round((now - state.currentSession.startTime) / 1000);
      if (duration >= 5) {
        allSessions.push({
          ...state.currentSession,
          endTime: now,
          duration,
        });
      }
    }

    if (allSessions.length === 0) return;

    // Incremental: only send new sessions since last sync
    const lastCount = state.lastSyncedCount[todayKey] || 0;
    const newSessions = allSessions.slice(lastCount);

    if (newSessions.length === 0) return;

    const apiUrl = `${state.apiBaseUrl}/api/sessions`;

    try {
      const res = await fetch(apiUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${state.syncToken}`,
        },
        body: JSON.stringify({ sessions: newSessions }),
      });

      if (res.ok) {
        // Update synced count on success
        await saveState({
          lastSync: Date.now(),
          lastSyncedCount: {
            ...state.lastSyncedCount,
            [todayKey]: allSessions.length,
          },
        });
        console.log(`[ToDay] Synced ${newSessions.length} new sessions`);
      } else {
        console.warn(`[ToDay] Sync failed: ${res.status}`);
      }
    } catch {
      // Server unavailable — will retry next cycle
    }
  } catch (e) {
    console.error("[ToDay] Sync error:", e);
  }
}

// ─── Local Cache Cleanup ───

async function cleanup() {
  const state = await getState();
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 30);
  const cutoffKey = cutoff.toISOString().split("T")[0];

  const cleaned = {};
  for (const [key, sessions] of Object.entries(state.sessions)) {
    if (key >= cutoffKey) {
      cleaned[key] = sessions;
    }
  }

  // Also clean old lastSyncedCount entries
  const cleanedCount = {};
  for (const [key, count] of Object.entries(state.lastSyncedCount)) {
    if (key >= cutoffKey) {
      cleanedCount[key] = count;
    }
  }

  await saveState({ sessions: cleaned, lastSyncedCount: cleanedCount });
}

// ─── Alarms ───

chrome.alarms.create("heartbeat", { periodInMinutes: HEARTBEAT_INTERVAL / 60 });
chrome.alarms.create("sync", { periodInMinutes: SYNC_INTERVAL });
chrome.alarms.create("cleanup", { periodInMinutes: 60 });

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "heartbeat") heartbeat();
  if (alarm.name === "sync") syncToServer();
  if (alarm.name === "cleanup") cleanup();
});

chrome.tabs.onActivated.addListener(() => heartbeat());
chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "complete") heartbeat();
});

heartbeat();

console.log("[ToDay] Extension loaded — session tracking started");
```

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add extension/src/background.js extension/manifest.json
git commit -m "feat: extension incremental sync with sync token auth"
```

---

### Task 7: Extension — Popup Settings UI

**Files:**
- Modify: `extension/src/popup.html`
- Modify: `extension/src/popup.js`

- [ ] **Step 1: Add settings section to popup.html**

In `extension/src/popup.html`, add before the closing `</body>` tag (after the footer div, before the `<script>` tag):

Replace the footer div and everything after it with:

```html
  <div class="divider"></div>

  <div class="settings" id="settingsSection" style="display:none;">
    <div class="settings-title">同步设置</div>
    <div class="settings-field">
      <label for="syncTokenInput">同步令牌</label>
      <input type="text" id="syncTokenInput" placeholder="从 Dashboard 设置中复制" />
    </div>
    <div class="settings-field">
      <label for="apiBaseInput">服务器地址</label>
      <input type="text" id="apiBaseInput" placeholder="https://to-day-ten.vercel.app" />
    </div>
    <div class="settings-actions">
      <button id="saveSettingsBtn">保存</button>
      <span id="saveStatus" class="save-status"></span>
    </div>
  </div>

  <div class="footer">
    <span class="footer-text">ToDay Browser Extension</span>
    <div style="display:flex; align-items:center; gap:12px;">
      <a class="dashboard-link" id="settingsToggle">设置</a>
      <a class="dashboard-link" id="dashboardLink">Dashboard →</a>
    </div>
  </div>

  <script src="popup.js"></script>
</body>
```

Add these styles inside the `<style>` block:

```css
    .settings {
      padding: 16px 20px;
    }

    .settings-title {
      font-size: 12px;
      color: #8A7D6B;
      margin-bottom: 12px;
      font-weight: 500;
    }

    .settings-field {
      margin-bottom: 12px;
    }

    .settings-field label {
      display: block;
      font-size: 11px;
      color: #8A7D6B;
      margin-bottom: 4px;
    }

    .settings-field input {
      width: 100%;
      padding: 8px 10px;
      border: 1px solid #E6DFD3;
      border-radius: 8px;
      background: #FDFBF7;
      font-size: 12px;
      color: #2C2418;
      outline: none;
      font-family: ui-monospace, monospace;
    }

    .settings-field input:focus {
      border-color: #C4713E;
    }

    .settings-actions {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .settings-actions button {
      background: #C4713E;
      color: white;
      border: none;
      border-radius: 8px;
      padding: 6px 16px;
      font-size: 12px;
      cursor: pointer;
    }

    .settings-actions button:hover {
      opacity: 0.9;
    }

    .save-status {
      font-size: 11px;
      color: #10b981;
    }
```

- [ ] **Step 2: Update popup.js with settings logic**

Replace the entire contents of `extension/src/popup.js`:

```javascript
const DEFAULT_API_BASE = "https://to-day-ten.vercel.app";

function formatDuration(seconds) {
  if (seconds < 60) return `${seconds}s`;
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

function formatTime(timestamp) {
  const d = new Date(timestamp);
  return d.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false });
}

async function render() {
  const todayKey = new Date().toISOString().split("T")[0];
  const result = await chrome.storage.local.get(["sessions", "currentSession", "syncToken"]);
  const closedSessions = result.sessions?.[todayKey] || [];

  // Include current active session
  const allSessions = [...closedSessions];
  if (result.currentSession) {
    const now = Date.now();
    const duration = Math.round((now - result.currentSession.startTime) / 1000);
    if (duration >= 10) {
      allSessions.push({
        ...result.currentSession,
        endTime: now,
        duration,
      });
    }
  }

  // Sort by start time (newest first)
  allSessions.sort((a, b) => b.startTime - a.startTime);

  // Total time
  const totalSeconds = allSessions.reduce((sum, e) => sum + (e.duration || 0), 0);
  document.getElementById("totalTime").textContent = formatDuration(totalSeconds);

  // Update status indicator
  const statusDot = document.querySelector(".status-dot");
  const statusText = document.querySelector(".status span");
  if (result.syncToken) {
    statusDot.style.background = "#10b981";
    statusText.textContent = "已连接";
  } else {
    statusDot.style.background = "#f59e0b";
    statusText.textContent = "未同步";
  }

  // Render site list
  const siteList = document.getElementById("siteList");
  if (allSessions.length === 0) {
    siteList.innerHTML = '<div class="empty-state"><p>继续浏览，数据会自动出现</p></div>';
  } else {
    siteList.innerHTML = allSessions.map(session => `
      <div class="site-item">
        <span class="site-time-range">${formatTime(session.startTime)} - ${formatTime(session.endTime)}</span>
        <span class="site-name">${session.label || session.domain}</span>
        <span class="site-time">${formatDuration(session.duration || 0)}</span>
      </div>
    `).join("");
  }
}

// Settings toggle
let settingsVisible = false;
document.getElementById("settingsToggle").addEventListener("click", () => {
  settingsVisible = !settingsVisible;
  document.getElementById("settingsSection").style.display = settingsVisible ? "block" : "none";
  document.getElementById("settingsToggle").textContent = settingsVisible ? "收起" : "设置";
});

// Load saved settings
chrome.storage.local.get(["syncToken", "apiBaseUrl"], (result) => {
  document.getElementById("syncTokenInput").value = result.syncToken || "";
  document.getElementById("apiBaseInput").value = result.apiBaseUrl || DEFAULT_API_BASE;
});

// Save settings
document.getElementById("saveSettingsBtn").addEventListener("click", async () => {
  const syncToken = document.getElementById("syncTokenInput").value.trim();
  const apiBaseUrl = document.getElementById("apiBaseInput").value.trim() || DEFAULT_API_BASE;

  await chrome.storage.local.set({ syncToken: syncToken || null, apiBaseUrl });

  document.getElementById("saveStatus").textContent = "已保存";
  setTimeout(() => {
    document.getElementById("saveStatus").textContent = "";
  }, 2000);

  // Re-render to update status
  render();
});

// Open dashboard
document.getElementById("dashboardLink").addEventListener("click", async () => {
  const result = await chrome.storage.local.get(["apiBaseUrl"]);
  const base = result.apiBaseUrl || DEFAULT_API_BASE;
  chrome.tabs.create({ url: `${base}/dashboard` });
});

render();
```

- [ ] **Step 3: Verify extension**

1. Open `chrome://extensions`
2. Click "Load unpacked" → select `extension/` folder (or reload if already loaded)
3. Click extension icon → should see popup with site list
4. Click "设置" → settings section should appear with token + URL inputs
5. Paste a sync token, click "保存" → should show "已保存"
6. Status should change from "未同步" to "已连接"

- [ ] **Step 4: End-to-end verification**

1. Log into dashboard → Settings → copy sync token
2. Paste into extension settings → save
3. Browse some websites for 2-3 minutes
4. Open dashboard → Screen Time page → should show real data
5. Verify: categories, top sites, hourly chart should reflect actual browsing

- [ ] **Step 5: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add extension/src/popup.html extension/src/popup.js
git commit -m "feat: extension popup settings for sync token and API URL"
```

---

## Final Verification

After all tasks are complete:

- [ ] Dashboard Settings page shows sync token with copy button
- [ ] Extension popup has settings with token input
- [ ] Extension syncs incrementally (check console for "[ToDay] Synced N new sessions")
- [ ] Screen Time page shows real browsing data (not mock)
- [ ] Screen Time page shows empty state when no data
- [ ] Categories, top sites, hourly chart, weekly trend all render from real data
- [ ] Yesterday comparison works (shows "比昨天多/少 X%" or hidden when no yesterday data)
