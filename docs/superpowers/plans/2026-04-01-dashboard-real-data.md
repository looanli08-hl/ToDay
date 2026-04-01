# Dashboard Real Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hardcoded placeholder data on the web dashboard with real user data from Supabase (health data from iOS, browsing data from extension, mood records).

**Architecture:** New `/api/dashboard` route queries three Supabase tables (`data_points`, `browsing_sessions`, `mood_records`) for today's data and returns aggregated stats + timeline. Dashboard page fetches this API on mount and renders real data or an empty-state guide.

**Tech Stack:** Next.js 16 App Router, `@supabase/ssr`, Supabase (data_points, browsing_sessions, mood_records tables)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `web/src/app/api/dashboard/route.ts` | Create | Aggregation API — queries 3 tables, returns stats + timeline |
| `web/src/app/dashboard/page.tsx` | Modify | Fetch real data, render stats/timeline/empty state |

---

### Task 1: Create Dashboard API Route

**Files:**
- Create: `web/src/app/api/dashboard/route.ts`

- [ ] **Step 1: Create the API route**

This follows the same auth pattern as the existing `/api/screen-time/route.ts` — uses `resolveUserId` to accept sync_token or session auth.

```ts
import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";

async function resolveUserId(req: NextRequest) {
  const authHeader = req.headers.get("authorization");
  if (authHeader?.startsWith("Bearer ")) {
    const token = authHeader.slice(7).trim();
    const supabase = await createServerSupabaseClient();
    const { data: userId } = await supabase.rpc("get_user_id_by_sync_token", { token });
    if (userId) return userId as string;
  }

  const tokenParam = new URL(req.url).searchParams.get("token");
  if (tokenParam) {
    const supabase = await createServerSupabaseClient();
    const { data: userId } = await supabase.rpc("get_user_id_by_sync_token", { token: tokenParam });
    if (userId) return userId as string;
  }

  const supabase = await createServerSupabaseClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user?.id || null;
}

function todayRange() {
  const today = new Date().toISOString().split("T")[0];
  return { start: `${today}T00:00:00`, end: `${today}T23:59:59.999` };
}

function formatMinutes(minutes: number): string {
  if (minutes < 60) return `${minutes}m`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m > 0 ? `${h}h ${m}m` : `${h}h`;
}

export async function GET(req: NextRequest) {
  try {
    const userId = await resolveUserId(req);
    if (!userId) {
      return Response.json({ error: "Not authenticated" }, { status: 401 });
    }

    const supabase = await createServerSupabaseClient();
    const { start, end } = todayRange();

    // Query 1: data_points for today (health data from iOS)
    const { data: dataPoints } = await supabase
      .from("data_points")
      .select("type, value, timestamp")
      .eq("user_id", userId)
      .gte("timestamp", start)
      .lte("timestamp", end)
      .order("timestamp", { ascending: false });

    // Query 2: browsing_sessions for today (from browser extension)
    const { data: sessions } = await supabase
      .from("browsing_sessions")
      .select("domain, category, duration_seconds, start_time")
      .eq("user_id", userId)
      .gte("start_time", start)
      .lte("start_time", end)
      .order("start_time", { ascending: false });

    // Query 3: mood_records for today
    const { data: moods } = await supabase
      .from("mood_records")
      .select("emoji, name, created_at")
      .eq("user_id", userId)
      .gte("created_at", start)
      .lte("created_at", end)
      .order("created_at", { ascending: false });

    // --- Aggregate stats ---

    // Steps: sum all step events
    let steps = 0;
    let sleepHours = 0;
    const healthEvents: { time: string; type: string; label: string }[] = [];

    for (const dp of dataPoints || []) {
      const val = dp.value as Record<string, unknown>;
      const time = new Date(dp.timestamp).toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
        timeZone: "Asia/Shanghai",
      });

      if (dp.type === "steps" && typeof val.duration === "number") {
        steps += Number(val.duration) || 0;
        healthEvents.push({ time, type: "activity", label: `步行 · ${val.displayName || "活动"}` });
      } else if (dp.type === "sleep" && typeof val.duration === "number") {
        sleepHours += (Number(val.duration) || 0) / 3600;
        healthEvents.push({ time, type: "sleep", label: `睡眠 · ${(Number(val.duration) / 3600).toFixed(1)}小时` });
      } else if (dp.type === "workout") {
        healthEvents.push({ time, type: "activity", label: val.displayName as string || "运动" });
      } else if (dp.type !== "mood") {
        healthEvents.push({ time, type: "health", label: val.displayName as string || dp.type });
      }
    }

    // Screen time: sum browsing session durations
    const screenTimeMinutes = sessions
      ? Math.round(sessions.reduce((sum, s) => sum + s.duration_seconds, 0) / 60)
      : 0;

    // Build browsing timeline events (group by hour + category)
    const browsingEvents: { time: string; type: string; label: string }[] = [];
    const categoryByHour = new Map<string, Map<string, number>>();
    for (const s of sessions || []) {
      const hour = new Date(s.start_time).toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
        timeZone: "Asia/Shanghai",
      });
      const hourKey = hour.split(":")[0] + ":00";
      if (!categoryByHour.has(hourKey)) categoryByHour.set(hourKey, new Map());
      const catMap = categoryByHour.get(hourKey)!;
      const cat = s.category || "其他";
      catMap.set(cat, (catMap.get(cat) || 0) + s.duration_seconds);
    }
    for (const [hour, catMap] of categoryByHour) {
      const topCat = Array.from(catMap.entries()).sort((a, b) => b[1] - a[1])[0];
      if (topCat) {
        browsingEvents.push({
          time: hour,
          type: "screen",
          label: `屏幕时间 · ${topCat[0]} ${formatMinutes(Math.round(topCat[1] / 60))}`,
        });
      }
    }

    // Mood
    const moodLatest = moods && moods.length > 0 ? moods[0] : null;
    const moodCount = moods?.length || 0;
    const moodEvents: { time: string; type: string; label: string }[] = (moods || []).map((m) => ({
      time: new Date(m.created_at).toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
        timeZone: "Asia/Shanghai",
      }),
      type: "mood",
      label: `记录心情 · ${m.emoji} ${m.name}`,
    }));

    // Merge and sort timeline
    const timeline = [...healthEvents, ...browsingEvents, ...moodEvents]
      .sort((a, b) => b.time.localeCompare(a.time))
      .slice(0, 20);

    return Response.json({
      stats: {
        steps,
        sleep_hours: Math.round(sleepHours * 10) / 10,
        screen_time_minutes: screenTimeMinutes,
        mood_latest: moodLatest ? { emoji: moodLatest.emoji, name: moodLatest.name } : null,
        mood_count: moodCount,
      },
      timeline,
      has_data: (dataPoints?.length || 0) + (sessions?.length || 0) + (moods?.length || 0) > 0,
    });
  } catch (err) {
    console.error("[dashboard] Error:", err);
    return Response.json({
      stats: { steps: 0, sleep_hours: 0, screen_time_minutes: 0, mood_latest: null, mood_count: 0 },
      timeline: [],
      has_data: false,
    });
  }
}
```

- [ ] **Step 2: Verify build passes**

Run: `cd /Users/looanli/Projects/ToDay/web && npx next build 2>&1 | tail -5`
Expected: `✓ Compiled successfully`

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/api/dashboard/route.ts
git commit -m "feat: add /api/dashboard aggregation endpoint for real user data"
```

---

### Task 2: Connect Dashboard Page to Real Data

**Files:**
- Modify: `web/src/app/dashboard/page.tsx`

- [ ] **Step 1: Replace the entire dashboard page with real data version**

Replace the full file content:

```tsx
"use client";

import { useState, useEffect } from "react";
import { Card } from "@/components/ui/card";
import {
  Moon,
  Layers,
  TrendingUp,
  Clock,
  Zap,
  Heart,
  ArrowUpRight,
  Activity,
  Monitor,
  Smartphone,
  Globe,
} from "lucide-react";
import { EchoSymbol } from "@/components/echo-symbol";
import { createClient } from "@/lib/supabase/client";
import Link from "next/link";

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 6) return "夜深了";
  if (hour < 12) return "早上好";
  if (hour < 14) return "中午好";
  if (hour < 18) return "下午好";
  if (hour < 22) return "晚上好";
  return "夜深了";
}

function formatMinutes(minutes: number): string {
  if (minutes === 0) return "--";
  if (minutes < 60) return `${minutes} 分钟`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m > 0 ? `${h}h ${m}m` : `${h} 小时`;
}

interface DashboardStats {
  steps: number;
  sleep_hours: number;
  screen_time_minutes: number;
  mood_latest: { emoji: string; name: string } | null;
  mood_count: number;
}

interface TimelineEvent {
  time: string;
  type: string;
  label: string;
}

interface DashboardData {
  stats: DashboardStats;
  timeline: TimelineEvent[];
  has_data: boolean;
}

export default function DashboardPage() {
  const [userName, setUserName] = useState("");
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const greeting = getGreeting();
  const now = new Date();
  const dateStr = now.toLocaleDateString("zh-CN", {
    month: "long",
    day: "numeric",
    weekday: "long",
  });

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data: { user } }) => {
      if (user) {
        setUserName(
          user.user_metadata?.display_name ||
            user.email?.split("@")[0] ||
            ""
        );

        // Fetch sync token for API auth
        const { data: profile } = await supabase
          .from("profiles")
          .select("sync_token")
          .eq("id", user.id)
          .single();

        if (profile?.sync_token) {
          try {
            const res = await fetch(`/api/dashboard?token=${profile.sync_token}`);
            const json = await res.json();
            setData(json);
          } catch {
            setData({ stats: { steps: 0, sleep_hours: 0, screen_time_minutes: 0, mood_latest: null, mood_count: 0 }, timeline: [], has_data: false });
          }
        }
      }
      setLoading(false);
    });
  }, []);

  const stats = data?.stats;

  const statCards = [
    {
      label: "活动时间",
      value: stats?.steps ? `${stats.steps.toLocaleString()} 步` : "--",
      sub: "运动 · 步行",
      icon: Zap,
    },
    {
      label: "睡眠",
      value: stats?.sleep_hours ? `${stats.sleep_hours} 小时` : "--",
      sub: "昨晚",
      icon: Moon,
    },
    {
      label: "屏幕时间",
      value: stats?.screen_time_minutes ? formatMinutes(stats.screen_time_minutes) : "--",
      sub: "今日总计",
      icon: Layers,
    },
    {
      label: "心情",
      value: stats?.mood_latest ? stats.mood_latest.emoji : "--",
      sub: stats?.mood_count ? `${stats.mood_count} 条记录` : "暂无记录",
      icon: Heart,
    },
  ];

  return (
    <div className="min-h-screen">
      {/* Hero Section */}
      <div className="px-12 pt-12 pb-10">
        <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
          {greeting}{userName ? `，${userName}` : ""}
        </h1>
        <p className="text-base text-muted-foreground mt-2">{dateStr}</p>
      </div>

      <div className="px-12 pb-12 space-y-8">
        {/* Stat Cards */}
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {statCards.map((card) => (
            <Card
              key={card.label}
              className="border border-border/40 bg-card rounded-xl p-6 hover:shadow-sm transition-shadow duration-300"
            >
              <div className="flex items-start justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">{card.label}</p>
                  <p className={`font-display text-2xl font-normal mt-2 ${card.value === "--" ? "text-muted-foreground/30" : "text-foreground"}`}>
                    {loading ? (
                      <span className="inline-block w-16 h-7 bg-muted-foreground/10 rounded animate-pulse" />
                    ) : (
                      card.value
                    )}
                  </p>
                  <p className="text-xs text-muted-foreground/60 mt-1">{card.sub}</p>
                </div>
                <card.icon className="h-4 w-4 text-muted-foreground/25" strokeWidth={1.5} />
              </div>
            </Card>
          ))}
        </div>

        {/* Main Grid */}
        <div className="grid gap-6 xl:grid-cols-3">
          {/* Timeline */}
          <Card className="xl:col-span-2 border border-border/40 bg-card rounded-xl p-6">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-2.5">
                <Activity className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                <h2 className="font-display text-lg text-foreground">今日时间线</h2>
              </div>
              <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                实时
              </div>
            </div>

            {loading ? (
              <div className="space-y-3">
                {[1, 2, 3].map((i) => (
                  <div key={i} className="flex items-center gap-4 py-3">
                    <span className="w-12 h-4 bg-muted-foreground/10 rounded animate-pulse" />
                    <div className="h-2 w-2 rounded-full bg-muted-foreground/10" />
                    <span className="flex-1 h-4 bg-muted-foreground/10 rounded animate-pulse" />
                  </div>
                ))}
              </div>
            ) : data?.timeline && data.timeline.length > 0 ? (
              <div className="space-y-0">
                {data.timeline.map((event, i) => (
                  <div key={i} className="flex items-center gap-4 py-3 border-b border-border/40 last:border-0">
                    <span className="text-sm font-mono text-muted-foreground w-12">{event.time}</span>
                    <div className="relative">
                      <div className={`h-2 w-2 rounded-full ${
                        event.type === "mood" ? "bg-pink-400" :
                        event.type === "sleep" ? "bg-indigo-400" :
                        event.type === "screen" ? "bg-amber-400" :
                        "bg-emerald-400"
                      }`} />
                      {i < data.timeline.length - 1 && (
                        <div className="absolute top-3 left-[3px] h-8 w-px bg-border/60" />
                      )}
                    </div>
                    <div className="flex-1">
                      <p className="text-sm text-foreground/80">{event.label}</p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="rounded-xl border border-dashed border-border/50 p-8 text-center">
                <p className="text-sm text-muted-foreground mb-4">
                  连接你的设备，开始记录生活
                </p>
                <div className="flex justify-center gap-3">
                  <Link
                    href="/dashboard/connectors"
                    className="flex items-center gap-2 rounded-full border border-border/50 px-4 py-2 text-sm text-muted-foreground hover:text-foreground hover:border-border transition-colors"
                  >
                    <Globe className="h-4 w-4" strokeWidth={1.5} />
                    安装浏览器扩展
                  </Link>
                  <Link
                    href="/dashboard/settings"
                    className="flex items-center gap-2 rounded-full border border-border/50 px-4 py-2 text-sm text-muted-foreground hover:text-foreground hover:border-border transition-colors"
                  >
                    <Smartphone className="h-4 w-4" strokeWidth={1.5} />
                    连接手机 App
                  </Link>
                </div>
              </div>
            )}
          </Card>

          {/* Right Column */}
          <div className="space-y-6">
            {/* Echo AI */}
            <Card className="border border-border/40 bg-card rounded-xl p-6">
              <div className="flex items-center gap-2 mb-4">
                <EchoSymbol size={15} className="text-primary" />
                <h2 className="font-display text-lg text-foreground">Echo</h2>
              </div>
              <div className="rounded-xl bg-background p-4 mb-3">
                <p className="text-sm text-foreground/70 leading-relaxed">
                  「今天看起来很充实。下午记得休息一下眼睛」
                </p>
                <p className="mt-2 text-[11px] text-muted-foreground">Echo · 刚刚</p>
              </div>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="跟 Echo 说点什么..."
                  className="flex-1 rounded-lg border border-border bg-background px-4 py-2.5 text-sm placeholder:text-muted-foreground/50 outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40 transition-all"
                />
                <button className="bg-primary text-primary-foreground rounded-lg px-4 py-2 text-sm font-medium hover:opacity-90 transition-opacity">
                  发送
                </button>
              </div>
            </Card>

            {/* Weekly Activity */}
            <Card className="border border-border/40 bg-card rounded-xl p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <TrendingUp className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                  <h2 className="font-display text-lg text-foreground">本周活跃度</h2>
                </div>
                <button className="text-xs text-muted-foreground hover:text-foreground flex items-center gap-0.5 transition-colors">
                  详情 <ArrowUpRight className="h-3 w-3" />
                </button>
              </div>
              <div className="flex items-end justify-between gap-2 h-24">
                {["一", "二", "三", "四", "五", "六", "日"].map((d) => (
                  <div key={d} className="flex flex-col items-center gap-1.5 flex-1">
                    <div
                      className="w-full rounded-lg bg-muted-foreground/10 transition-all duration-500"
                      style={{ height: "20%" }}
                    />
                    <span className="text-[11px] text-muted-foreground">{d}</span>
                  </div>
                ))}
              </div>
            </Card>

            {/* Life Pulse */}
            <Card className="border border-border/40 bg-card rounded-xl p-6">
              <div className="flex items-center gap-2 mb-3">
                <Activity className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                <h2 className="font-display text-lg text-foreground">生活脉搏</h2>
              </div>
              <p className="text-sm leading-relaxed text-muted-foreground">
                连接你的手机和电脑后，ToDay 会自动分析你的生活节奏，给出个性化的洞察。
              </p>
            </Card>
          </div>
        </div>

        {/* Quick Actions */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <p className="text-sm text-muted-foreground mb-3">快速操作</p>
          <div className="flex flex-wrap gap-2">
            {[
              { icon: Heart, label: "记录心情" },
              { icon: Clock, label: "补充时段" },
              { icon: Monitor, label: "查看屏幕时间", href: "/dashboard/screen-time" },
              { icon: Heart, label: "跟 Echo 聊天", href: "/dashboard/echo" },
              { icon: TrendingUp, label: "周报分析" },
            ].map((action) => (
              action.href ? (
                <Link
                  key={action.label}
                  href={action.href}
                  className="flex items-center gap-2 rounded-full border border-border/50 px-4 py-2 text-sm text-muted-foreground hover:text-foreground hover:border-border transition-colors"
                >
                  <action.icon className="h-4 w-4" strokeWidth={1.5} />
                  {action.label}
                </Link>
              ) : (
                <button
                  key={action.label}
                  className="flex items-center gap-2 rounded-full border border-border/50 px-4 py-2 text-sm text-muted-foreground hover:text-foreground hover:border-border transition-colors"
                >
                  <action.icon className="h-4 w-4" strokeWidth={1.5} />
                  {action.label}
                </button>
              )
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Verify build passes**

Run: `cd /Users/looanli/Projects/ToDay/web && npx next build 2>&1 | tail -5`
Expected: `✓ Compiled successfully`

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/dashboard/page.tsx
git commit -m "feat: dashboard displays real user data with loading and empty states"
```

---

### Task 3: End-to-End Verification

- [ ] **Step 1: Start dev server**

```bash
cd /Users/looanli/Projects/ToDay/web && npm run dev
```

- [ ] **Step 2: Test with no data (new user)**

1. Log in as a user with no data
2. Dashboard should show "--" for all stats
3. Timeline should show empty state with "连接你的设备" + two buttons
4. Stat cards should NOT show skeleton after loading completes

- [ ] **Step 3: Test with browsing data**

1. Set up browser extension with sync token
2. Browse for a few minutes
3. Refresh dashboard
4. Screen time card should show real minutes
5. Timeline should show browsing events grouped by hour

- [ ] **Step 4: Test API directly**

```bash
curl "http://localhost:3000/api/dashboard?token=YOUR_SYNC_TOKEN"
```

Expected: JSON with stats and timeline arrays

- [ ] **Step 5: Push to production**

```bash
cd /Users/looanli/Projects/ToDay
git push origin main
```
