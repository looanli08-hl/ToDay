# Pre-Launch Security Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 11 pre-launch issues: unified auth layer, API key management, dashboard proxy guard, email verification, GDPR-grade account operations, mood persistence, timeline stats, connector status, extension cleanup.

**Architecture:** Create a centralized `withAuth()` wrapper for all API routes, a Next.js 16 Proxy (`proxy.ts`) for dashboard page protection, soft-delete columns for GDPR compliance, and migrate localStorage-only features to Supabase persistence.

**Tech Stack:** Next.js 16, Supabase (SSR + client), TypeScript, Resend SMTP (configured in Supabase Dashboard)

**IMPORTANT:** This project uses Next.js 16. Middleware is renamed to **Proxy** — use `proxy.ts` with `export function proxy()`, NOT `middleware.ts`. Check `node_modules/next/dist/docs/` before writing any code that touches Next.js conventions.

---

## File Structure

### New files
| File | Responsibility |
|------|---------------|
| `src/lib/api/auth.ts` | `withAuth()` higher-order function for API route auth |
| `src/proxy.ts` | Next.js 16 Proxy — redirects unauthenticated users away from `/dashboard/*` |
| `src/lib/supabase/migrations/003_soft_delete.sql` | Adds `deleted_at` columns + updates RLS policies |
| `src/app/api/account/clear-data/route.ts` | Soft-delete user data |
| `src/app/api/account/delete/route.ts` | Soft-delete user account (30-day grace) |
| `src/app/api/account/export/route.ts` | Export all user data as JSON download |

### Modified files
| File | Change |
|------|--------|
| `src/app/api/echo/chat/route.ts` | Remove hardcoded API key, add `withAuth` |
| `src/app/api/echo/insight/route.ts` | Remove hardcoded API key, add `withAuth` |
| `src/app/api/sessions/route.ts` | Replace custom auth with `withAuth` |
| `src/app/api/screen-time/route.ts` | Replace `resolveUserId()` with `withAuth`, remove query param |
| `src/app/api/dashboard/route.ts` | Replace `resolveUserId()` with `withAuth`, remove query param |
| `src/app/api/data/route.ts` | Remove memoryStore, add `withAuth` |
| `src/app/auth/register/page.tsx` | Restore email verification redirect |
| `src/app/dashboard/mood/page.tsx` | Replace localStorage with Supabase persistence |
| `src/app/dashboard/settings/page.tsx` | Implement account operations + dynamic connector status |
| `src/app/dashboard/timeline/page.tsx` | Compute real stats, remove query param token usage |
| `src/app/dashboard/page.tsx` | Remove `?token=` from API calls (cookie auth works) |
| `src/app/dashboard/screen-time/page.tsx` | Remove token query param logic (cookie auth works) |
| `web/.env.local` | Add `DEEPSEEK_API_KEY` |
| `extension/manifest.json` | Remove localhost from host_permissions |

---

### Task 1: Create `withAuth()` unified auth layer

**Files:**
- Create: `src/lib/api/auth.ts`

- [ ] **Step 1: Create the auth helper file**

```typescript
// src/lib/api/auth.ts
import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";

type AuthenticatedHandler = (
  req: NextRequest,
  context: { userId: string }
) => Promise<Response>;

export function withAuth(handler: AuthenticatedHandler) {
  return async (req: NextRequest): Promise<Response> => {
    // 1. Try sync token from Authorization: Bearer header
    const authHeader = req.headers.get("authorization");
    if (authHeader?.startsWith("Bearer ")) {
      const token = authHeader.slice(7).trim();
      try {
        const supabase = await createServerSupabaseClient();
        const { data: userId } = await supabase.rpc(
          "get_user_id_by_sync_token",
          { token }
        );
        if (userId) {
          return handler(req, { userId: userId as string });
        }
      } catch {
        // Invalid token format or RPC error — fall through
      }
    }

    // 2. Try Supabase cookie session
    try {
      const supabase = await createServerSupabaseClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (user) {
        return handler(req, { userId: user.id });
      }
    } catch {
      // Session error — fall through
    }

    // 3. No auth — reject
    return Response.json(
      { error: "Authentication required" },
      { status: 401 }
    );
  };
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `cd /Users/looanli/Projects/ToDay/web && npx tsc --noEmit src/lib/api/auth.ts 2>&1 | head -20`

If there are import resolution issues with `tsc` standalone, verify with:
Run: `cd /Users/looanli/Projects/ToDay/web && npx next build 2>&1 | tail -20`

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay && git add web/src/lib/api/auth.ts
git commit -m "feat: add withAuth() unified API auth layer"
```

---

### Task 2: Move DeepSeek API key to environment variable

**Files:**
- Modify: `src/app/api/echo/chat/route.ts`
- Modify: `src/app/api/echo/insight/route.ts`
- Modify: `.env.local`

- [ ] **Step 1: Update `.env.local`**

Add to the end of `web/.env.local`:
```
DEEPSEEK_API_KEY=sk-94d311f460e54b4cac9c216ed8d5af36
```

- [ ] **Step 2: Update echo/chat/route.ts — remove hardcoded key, add withAuth**

Replace the entire file with:

```typescript
// src/app/api/echo/chat/route.ts
import { NextRequest } from "next/server";
import { withAuth } from "@/lib/api/auth";

const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";

const BASE_PROMPT = `你是 Echo，用户生活中温暖而有洞察力的 AI 伙伴。你不是通用 AI 助手——你是一个了解用户生活节奏的朋友。

你可以帮助用户：
- 回顾和反思今天的经历
- 分析生活模式和习惯
- 提供情绪支持和建议
- 记录想法和灵感
- 规划日程和目标

用中文回应。`;

const PERSONALITY_PROMPTS: Record<string, string> = {
  gentle: `你的风格：温柔内敛。安静、真诚、有同理心。说话轻声细语，像一位默默陪伴的老朋友。不啰嗦，但每句话都有温度。适当使用 emoji，不过度。`,
  positive: `你的风格：积极阳光。热情、鼓励、充满正能量。总是能看到事情好的一面，用你的热情感染用户。语气轻快活泼，善用 emoji。`,
  rational: `你的风格：克制理性。冷静、客观、逻辑清晰。用数据和事实说话，帮用户理性分析问题。语气沉稳，少用 emoji，注重深度。`,
};

export const POST = withAuth(async (req: NextRequest) => {
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) {
    return Response.json(
      { error: "AI service not configured" },
      { status: 503 }
    );
  }

  const { messages, personality } = await req.json();

  const personalityPrompt =
    PERSONALITY_PROMPTS[personality] || PERSONALITY_PROMPTS.gentle;
  const systemPrompt = `${BASE_PROMPT}\n\n${personalityPrompt}`;

  const apiMessages = [
    { role: "system" as const, content: systemPrompt },
    ...messages,
  ];

  const response = await fetch(DEEPSEEK_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: apiMessages,
      temperature: 0.7,
      max_tokens: 2048,
      stream: true,
    }),
  });

  if (!response.ok) {
    return Response.json(
      { error: "AI service unavailable" },
      { status: response.status }
    );
  }

  return new Response(response.body, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
});
```

- [ ] **Step 3: Update echo/insight/route.ts — remove hardcoded key, add withAuth**

Replace the entire file with:

```typescript
// src/app/api/echo/insight/route.ts
import { NextRequest } from "next/server";
import { withAuth } from "@/lib/api/auth";

const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";

const SYSTEM_PROMPT = `你是 Echo，用户的数字生活伙伴。你了解他们的生活数据，用这些来帮助他们更深地认识自己、更好地生活。

你可以：肯定好的习惯、温柔地提醒、共鸣情绪、感知节奏变化、引发自省、发现跨维度的模式、或只是简单地陪伴。

说什么取决于数据里什么最值得此刻说。像一个真正了解对方的老朋友那样说话。

规则：
- 一句话，不超过50字，中文
- 绝不复述原始数据（如"你今天走了8000步"）
- 绝不给泛泛的健康建议（如"记得多喝水"）
- 根据当前时间调整语气（早上温暖鼓励、深夜关心）
- 如果数据充足，优先做跨维度关联
- 如果数据不多，简单陪伴也可以
- 用「」包裹你的话`;

const NO_DATA_MESSAGE = "我正在学习倾听你的生活节奏。";

export const POST = withAuth(async (req: NextRequest) => {
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) {
    return Response.json({ message: NO_DATA_MESSAGE });
  }

  try {
    const body = await req.json();
    const { stats, timeline_count, has_data, hour, user_name } = body;

    if (!has_data) {
      return Response.json({ message: NO_DATA_MESSAGE });
    }

    const parts: string[] = [];
    parts.push(
      `当前时间：${hour < 6 ? "深夜" : hour < 12 ? "上午" : hour < 14 ? "中午" : hour < 18 ? "下午" : hour < 22 ? "晚上" : "深夜"}`
    );
    if (user_name) parts.push(`用户名：${user_name}`);
    parts.push("");
    parts.push("今日数据：");
    if (stats.steps > 0)
      parts.push(`- 步数：${stats.steps.toLocaleString()}`);
    if (stats.sleep_hours > 0)
      parts.push(`- 睡眠：${stats.sleep_hours}小时`);
    if (stats.screen_time_minutes > 0) {
      const h = Math.floor(stats.screen_time_minutes / 60);
      const m = stats.screen_time_minutes % 60;
      parts.push(
        `- 屏幕时间：${h > 0 ? h + "小时" : ""}${m > 0 ? m + "分钟" : ""}`
      );
    }
    if (stats.mood_latest) {
      parts.push(
        `- 心情：${stats.mood_latest.emoji} ${stats.mood_latest.name}（${stats.mood_count}条记录）`
      );
    }
    if (timeline_count > 0)
      parts.push(`- 今日事件数：${timeline_count}个`);

    parts.push("");
    parts.push("请基于以上数据，生成一句话。");

    const userPrompt = parts.join("\n");

    const response = await fetch(DEEPSEEK_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.8,
        max_tokens: 100,
        stream: false,
      }),
    });

    if (!response.ok) {
      return Response.json({ message: "在这里陪着你。" });
    }

    const result = await response.json();
    const message =
      result.choices?.[0]?.message?.content?.trim() || "在这里陪着你。";

    return Response.json({ message });
  } catch {
    return Response.json({ message: "在这里陪着你。" });
  }
});
```

- [ ] **Step 4: Commit**

```bash
cd /Users/looanli/Projects/ToDay && git add web/src/app/api/echo/chat/route.ts web/src/app/api/echo/insight/route.ts web/.env.local
git commit -m "security: move DeepSeek API key to env var, add auth to Echo endpoints"
```

---

### Task 3: Migrate all API routes to `withAuth`

**Files:**
- Modify: `src/app/api/sessions/route.ts`
- Modify: `src/app/api/screen-time/route.ts`
- Modify: `src/app/api/dashboard/route.ts`
- Modify: `src/app/api/data/route.ts`

- [ ] **Step 1: Rewrite sessions/route.ts**

Replace the entire file. The key change: remove custom Bearer check, use `withAuth` which provides `userId` directly.

```typescript
// src/app/api/sessions/route.ts
import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

interface SessionPayload {
  domain: string;
  label?: string;
  category: string;
  title?: string;
  startTime: number;
  endTime: number;
  duration: number;
}

export const POST = withAuth(async (req: NextRequest, { userId }) => {
  try {
    const body = await req.json();
    const sessions: SessionPayload[] = body.sessions;

    if (!Array.isArray(sessions) || sessions.length === 0) {
      return Response.json(
        { error: "sessions must be a non-empty array" },
        { status: 400 }
      );
    }

    const supabase = await createServerSupabaseClient();
    let inserted = 0;
    let duplicates = 0;

    for (const session of sessions) {
      if (
        !session.domain ||
        !session.category ||
        !session.startTime ||
        !session.endTime
      ) {
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
});
```

- [ ] **Step 2: Rewrite screen-time/route.ts**

Replace the entire file. Key changes: remove `resolveUserId()`, remove query param token, use `withAuth`.

```typescript
// src/app/api/screen-time/route.ts
import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

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

export const GET = withAuth(async (req: NextRequest, { userId }) => {
  try {
    const supabase = await createServerSupabaseClient();
    const { searchParams } = new URL(req.url);
    const today =
      searchParams.get("date") ||
      new Date().toISOString().split("T")[0];

    const todayRange = getDateRange(today);

    const yesterdayDate = new Date(today);
    yesterdayDate.setDate(yesterdayDate.getDate() - 1);
    const yesterdayStr = yesterdayDate.toISOString().split("T")[0];
    const yesterdayRange = getDateRange(yesterdayStr);

    // Query 1: Today's total
    const { data: totalData } = await supabase
      .from("browsing_sessions")
      .select("duration_seconds")
      .eq("user_id", userId)
      .gte("start_time", todayRange.start)
      .lte("start_time", todayRange.end);

    const totalMinutes = totalData
      ? Math.round(
          totalData.reduce((sum, r) => sum + r.duration_seconds, 0) / 60
        )
      : 0;

    // Query 2: Categories
    const { data: catRows } = await supabase
      .from("browsing_sessions")
      .select("category, duration_seconds")
      .eq("user_id", userId)
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

    // Query 3: Top Sites
    const { data: siteRows } = await supabase
      .from("browsing_sessions")
      .select("domain, title, duration_seconds")
      .eq("user_id", userId)
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

    // Query 4: Hourly distribution
    const { data: hourlyRows } = await supabase
      .from("browsing_sessions")
      .select("start_time, duration_seconds")
      .eq("user_id", userId)
      .gte("start_time", todayRange.start)
      .lte("start_time", todayRange.end);

    const hourly = new Array(24).fill(0);
    for (const row of hourlyRows || []) {
      const hour = new Date(row.start_time).getHours();
      hourly[hour] += row.duration_seconds / 60;
    }
    const hourlyRounded = hourly.map((v: number) => Math.round(v));

    // Query 5: Yesterday total
    const { data: yesterdayData } = await supabase
      .from("browsing_sessions")
      .select("duration_seconds")
      .eq("user_id", userId)
      .gte("start_time", yesterdayRange.start)
      .lte("start_time", yesterdayRange.end);

    const yesterdayMinutes = yesterdayData
      ? Math.round(
          yesterdayData.reduce((sum, r) => sum + r.duration_seconds, 0) / 60
        )
      : 0;

    // Query 6: Weekly (7 days)
    const weeklyStart = new Date(today);
    weeklyStart.setDate(weeklyStart.getDate() - 6);
    const weeklyStartStr = weeklyStart.toISOString().split("T")[0];

    const { data: weeklyRows } = await supabase
      .from("browsing_sessions")
      .select("start_time, duration_seconds")
      .eq("user_id", userId)
      .gte("start_time", `${weeklyStartStr}T00:00:00`)
      .lte("start_time", todayRange.end);

    const weeklyMap = new Map<string, number>();
    for (const row of weeklyRows || []) {
      const dateKey = row.start_time.split("T")[0];
      weeklyMap.set(
        dateKey,
        (weeklyMap.get(dateKey) || 0) + row.duration_seconds
      );
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
});
```

- [ ] **Step 3: Rewrite dashboard/route.ts**

Replace the entire file. Key changes: remove `resolveUserId()`, use `withAuth`.

```typescript
// src/app/api/dashboard/route.ts
import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

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

export const GET = withAuth(async (req: NextRequest, { userId }) => {
  try {
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
        healthEvents.push({
          time,
          type: "activity",
          label: `步行 · ${val.displayName || "活动"}`,
        });
      } else if (dp.type === "sleep" && typeof val.duration === "number") {
        sleepHours += (Number(val.duration) || 0) / 3600;
        healthEvents.push({
          time,
          type: "sleep",
          label: `睡眠 · ${(Number(val.duration) / 3600).toFixed(1)}小时`,
        });
      } else if (dp.type === "workout") {
        healthEvents.push({
          time,
          type: "activity",
          label: (val.displayName as string) || "运动",
        });
      } else if (dp.type !== "mood") {
        healthEvents.push({
          time,
          type: "health",
          label: (val.displayName as string) || dp.type,
        });
      }
    }

    const screenTimeMinutes = sessions
      ? Math.round(
          sessions.reduce((sum, s) => sum + s.duration_seconds, 0) / 60
        )
      : 0;

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
      if (!categoryByHour.has(hourKey))
        categoryByHour.set(hourKey, new Map());
      const catMap = categoryByHour.get(hourKey)!;
      const cat = s.category || "其他";
      catMap.set(cat, (catMap.get(cat) || 0) + s.duration_seconds);
    }
    for (const [hour, catMap] of categoryByHour) {
      const topCat = Array.from(catMap.entries()).sort(
        (a, b) => b[1] - a[1]
      )[0];
      if (topCat) {
        browsingEvents.push({
          time: hour,
          type: "screen",
          label: `屏幕时间 · ${topCat[0]} ${formatMinutes(Math.round(topCat[1] / 60))}`,
        });
      }
    }

    const moodLatest = moods && moods.length > 0 ? moods[0] : null;
    const moodCount = moods?.length || 0;
    const moodEvents: { time: string; type: string; label: string }[] = (
      moods || []
    ).map((m) => ({
      time: new Date(m.created_at).toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
        timeZone: "Asia/Shanghai",
      }),
      type: "mood",
      label: `记录心情 · ${m.emoji} ${m.name}`,
    }));

    const timeline = [...healthEvents, ...browsingEvents, ...moodEvents]
      .sort((a, b) => b.time.localeCompare(a.time))
      .slice(0, 20);

    return Response.json({
      stats: {
        steps,
        sleep_hours: Math.round(sleepHours * 10) / 10,
        screen_time_minutes: screenTimeMinutes,
        mood_latest: moodLatest
          ? { emoji: moodLatest.emoji, name: moodLatest.name }
          : null,
        mood_count: moodCount,
      },
      timeline,
      has_data:
        (dataPoints?.length || 0) +
          (sessions?.length || 0) +
          (moods?.length || 0) >
        0,
    });
  } catch (err) {
    console.error("[dashboard] Error:", err);
    return Response.json({
      stats: {
        steps: 0,
        sleep_hours: 0,
        screen_time_minutes: 0,
        mood_latest: null,
        mood_count: 0,
      },
      timeline: [],
      has_data: false,
    });
  }
});
```

- [ ] **Step 4: Rewrite data/route.ts — remove memoryStore, add withAuth**

Replace the entire file:

```typescript
// src/app/api/data/route.ts
import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

export const POST = withAuth(async (req: NextRequest, { userId }) => {
  try {
    const body = await req.json();
    const { source, type, value, timestamp, metadata } = body;

    if (!source || !type || value === undefined || !timestamp) {
      return Response.json(
        { error: "Missing required fields: source, type, value, timestamp" },
        { status: 400 }
      );
    }

    const supabase = await createServerSupabaseClient();
    const { data, error } = await supabase.from("data_points").insert({
      user_id: userId,
      source,
      type,
      value: typeof value === "object" ? value : { raw: value },
      timestamp,
      metadata,
    }).select("id").single();

    if (error) {
      return Response.json({ error: "Failed to store data" }, { status: 500 });
    }

    return Response.json({ success: true, id: data.id });
  } catch {
    return Response.json({ error: "Invalid request body" }, { status: 400 });
  }
});

export const GET = withAuth(async (req: NextRequest, { userId }) => {
  const { searchParams } = new URL(req.url);
  const date = searchParams.get("date");
  const source = searchParams.get("source");

  const supabase = await createServerSupabaseClient();

  let query = supabase
    .from("data_points")
    .select("id, source, type, value, timestamp, metadata")
    .eq("user_id", userId)
    .order("timestamp", { ascending: false })
    .limit(200);

  if (source) {
    query = query.eq("source", source);
  }

  if (date) {
    query = query
      .gte("timestamp", `${date}T00:00:00`)
      .lt("timestamp", `${date}T23:59:59`);
  }

  const { data } = await query;

  return Response.json({
    data: data || [],
    count: data?.length || 0,
  });
});
```

- [ ] **Step 5: Build to verify all routes compile**

Run: `cd /Users/looanli/Projects/ToDay/web && npx next build 2>&1 | tail -30`

Expected: Build succeeds with no type errors in the modified files.

- [ ] **Step 6: Commit**

```bash
cd /Users/looanli/Projects/ToDay && git add web/src/app/api/sessions/route.ts web/src/app/api/screen-time/route.ts web/src/app/api/dashboard/route.ts web/src/app/api/data/route.ts
git commit -m "security: migrate all API routes to withAuth, remove memoryStore and query param auth"
```

---

### Task 3b: Fix client-side pages that use query param auth

**Files:**
- Modify: `src/app/dashboard/page.tsx`
- Modify: `src/app/dashboard/screen-time/page.tsx`

Since `withAuth` accepts cookie sessions (step 2 in auth resolution), client-side fetch calls from authenticated pages don't need to pass sync tokens at all — the browser sends session cookies automatically.

- [ ] **Step 1: Update dashboard/page.tsx — remove token from API calls**

In `src/app/dashboard/page.tsx`, replace lines 82-121 (the entire `supabase.auth.getUser().then(...)` callback body after `setUserName`) with:

```typescript
        // Fetch dashboard data (cookie auth — no token needed)
        try {
          const res = await fetch("/api/dashboard");
          const json = await res.json();
          setData(json);

          // Fetch Echo dynamic insight
          try {
            const echoRes = await fetch("/api/echo/insight", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                stats: json.stats,
                timeline_count: json.timeline?.length || 0,
                has_data: json.has_data,
                hour: new Date().getHours(),
                user_name: user.user_metadata?.display_name || "",
              }),
            });
            const echoJson = await echoRes.json();
            setEchoMessage(echoJson.message);
          } catch {
            setEchoMessage("在这里陪着你。");
          }
          setEchoLoading(false);
        } catch {
          setData({
            stats: {
              steps: 0,
              sleep_hours: 0,
              screen_time_minutes: 0,
              mood_latest: null,
              mood_count: 0,
            },
            timeline: [],
            has_data: false,
          });
          setEchoLoading(false);
        }
```

This removes the sync_token fetch and query param from both `/api/dashboard` and `/api/echo/insight` calls. Cookie session handles auth.

- [ ] **Step 2: Update screen-time/page.tsx — remove token logic**

In `src/app/dashboard/screen-time/page.tsx`, replace lines 60-86 (the token fetch + API call block) with:

```typescript
      fetch(`/api/screen-time?date=${today}&tz=${tz}`)
        .then((res) => {
          if (!res.ok) return null;
          return res.json();
        })
        .then((json) => {
          if (json) setData(json);
          setLoading(false);
        })
        .catch(() => {
          setLoading(false);
        });
```

This removes all token-related logic. Cookie session handles auth.

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay && git add web/src/app/dashboard/page.tsx web/src/app/dashboard/screen-time/page.tsx
git commit -m "fix: remove query param auth from client pages, rely on cookie session"
```

---

### Task 4: Create Next.js 16 Proxy for dashboard auth guard

**Files:**
- Create: `src/proxy.ts`

**IMPORTANT:** Next.js 16 renamed Middleware to Proxy. The file MUST be `proxy.ts` (not `middleware.ts`) and export a function named `proxy`. See `node_modules/next/dist/docs/01-app/01-getting-started/16-proxy.md`.

- [ ] **Step 1: Create proxy.ts**

```typescript
// src/proxy.ts
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

export async function proxy(req: NextRequest) {
  const res = NextResponse.next();

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return req.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            res.cookies.set(name, value, options);
          });
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.redirect(new URL("/auth/login", req.url));
  }

  return res;
}

export const config = {
  matcher: ["/dashboard/:path*"],
};
```

- [ ] **Step 2: Build to verify proxy works**

Run: `cd /Users/looanli/Projects/ToDay/web && npx next build 2>&1 | tail -20`

Expected: Build succeeds, proxy.ts is recognized.

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay && git add web/src/proxy.ts
git commit -m "security: add Next.js 16 Proxy to guard dashboard routes"
```

---

### Task 5: Restore email verification flow

**Files:**
- Modify: `src/app/auth/register/page.tsx`

**Note:** Resend SMTP must be configured in Supabase Dashboard manually by the user. This task only handles the code changes.

- [ ] **Step 1: Update register/page.tsx to redirect to verify page**

In `src/app/auth/register/page.tsx`, replace lines 43-47:

Old:
```typescript
      // TODO: restore verify redirect when SMTP is fixed
      // router.push(`/auth/verify?email=${encodeURIComponent(email)}`);
      router.push("/dashboard");
      router.refresh();
```

New:
```typescript
      router.push(`/auth/verify?email=${encodeURIComponent(email)}`);
```

- [ ] **Step 2: Commit**

```bash
cd /Users/looanli/Projects/ToDay && git add web/src/app/auth/register/page.tsx
git commit -m "feat: restore email verification redirect after registration"
```

---

### Task 6: Database migration for soft delete

**Files:**
- Create: `src/lib/supabase/migrations/003_soft_delete.sql`

- [ ] **Step 1: Write migration SQL**

```sql
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
-- Drop and recreate affected policies

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

-- Add UPDATE policy for soft delete
CREATE POLICY "Users can update own sessions" ON browsing_sessions
  FOR UPDATE USING (auth.uid() = user_id);

-- mood_records
DROP POLICY IF EXISTS "Users can manage own moods" ON mood_records;
CREATE POLICY "Users can manage own moods" ON mood_records
  FOR ALL USING (auth.uid() = user_id AND deleted_at IS NULL);

-- 4. RPC: soft-delete user data (called by server with validated user_id)
CREATE OR REPLACE FUNCTION soft_delete_user_data(p_user_id UUID)
RETURNS void AS $$
  UPDATE data_points SET deleted_at = NOW() WHERE user_id = p_user_id AND deleted_at IS NULL;
  UPDATE browsing_sessions SET deleted_at = NOW() WHERE user_id = p_user_id AND deleted_at IS NULL;
  UPDATE mood_records SET deleted_at = NOW() WHERE user_id = p_user_id AND deleted_at IS NULL;
$$ LANGUAGE sql SECURITY DEFINER;

-- 5. RPC: soft-delete user account
CREATE OR REPLACE FUNCTION soft_delete_user_account(p_user_id UUID)
RETURNS void AS $$
  UPDATE profiles SET deleted_at = NOW() WHERE id = p_user_id AND deleted_at IS NULL;
  -- Also soft-delete all user data
  PERFORM soft_delete_user_data(p_user_id);
$$ LANGUAGE sql SECURITY DEFINER;
```

- [ ] **Step 2: Commit migration file**

```bash
cd /Users/looanli/Projects/ToDay && git add web/src/lib/supabase/migrations/003_soft_delete.sql
git commit -m "feat: add soft delete migration for GDPR-grade account operations"
```

**Note to executor:** This SQL must be run in Supabase SQL Editor manually before Task 7.

---

### Task 7: Account operations API routes + Settings UI

**Files:**
- Create: `src/app/api/account/clear-data/route.ts`
- Create: `src/app/api/account/delete/route.ts`
- Create: `src/app/api/account/export/route.ts`
- Modify: `src/app/dashboard/settings/page.tsx`

- [ ] **Step 1: Create clear-data route**

```typescript
// src/app/api/account/clear-data/route.ts
import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

export const POST = withAuth(async (req: NextRequest, { userId }) => {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("soft_delete_user_data", {
    p_user_id: userId,
  });

  if (error) {
    return Response.json({ error: "Failed to clear data" }, { status: 500 });
  }

  return Response.json({ cleared: true });
});
```

- [ ] **Step 2: Create delete account route**

```typescript
// src/app/api/account/delete/route.ts
import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

export const POST = withAuth(async (req: NextRequest, { userId }) => {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("soft_delete_user_account", {
    p_user_id: userId,
  });

  if (error) {
    return Response.json(
      { error: "Failed to delete account" },
      { status: 500 }
    );
  }

  // Sign out the user
  await supabase.auth.signOut();

  return Response.json({ deleted: true, grace_period_days: 30 });
});
```

- [ ] **Step 3: Create export route**

```typescript
// src/app/api/account/export/route.ts
import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

export const GET = withAuth(async (req: NextRequest, { userId }) => {
  const supabase = await createServerSupabaseClient();

  const [
    { data: profile },
    { data: dataPoints },
    { data: sessions },
    { data: moods },
  ] = await Promise.all([
    supabase
      .from("profiles")
      .select("id, display_name, plan, created_at")
      .eq("id", userId)
      .single(),
    supabase
      .from("data_points")
      .select("source, type, value, timestamp, metadata")
      .eq("user_id", userId)
      .order("timestamp", { ascending: false }),
    supabase
      .from("browsing_sessions")
      .select(
        "domain, label, category, title, start_time, end_time, duration_seconds, source"
      )
      .eq("user_id", userId)
      .order("start_time", { ascending: false }),
    supabase
      .from("mood_records")
      .select("emoji, name, note, created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false }),
  ]);

  const exportData = {
    exported_at: new Date().toISOString(),
    profile: profile || null,
    data_points: dataPoints || [],
    browsing_sessions: sessions || [],
    mood_records: moods || [],
  };

  return new Response(JSON.stringify(exportData, null, 2), {
    headers: {
      "Content-Type": "application/json",
      "Content-Disposition": `attachment; filename="today-export-${new Date().toISOString().split("T")[0]}.json"`,
    },
  });
});
```

- [ ] **Step 4: Rewrite settings/page.tsx with account operations + dynamic connector status**

Replace the entire `src/app/dashboard/settings/page.tsx` file. Key changes:
- Dynamic connector status (queries browsing_sessions and data_points counts)
- Working "Clear data" button with confirmation dialog (type "删除")
- Working "Delete account" button with 3-step confirmation (warning → email confirm → final)
- Data export link

```typescript
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
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
  Download,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";

const ECHO_PERSONALITIES = [
  {
    id: "gentle",
    label: "温柔内敛",
    description: "安静、体贴，像一位默默陪伴的朋友",
  },
  {
    id: "positive",
    label: "积极阳光",
    description: "热情、鼓励，总是给你正能量",
  },
  {
    id: "rational",
    label: "克制理性",
    description: "冷静、客观，用逻辑帮你分析问题",
  },
];

export default function SettingsPage() {
  const router = useRouter();
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [displayName, setDisplayName] = useState("...");
  const [echoPersonality, setEchoPersonality] = useState(() => {
    if (typeof window === "undefined") return "gentle";
    return localStorage.getItem("echo-personality") || "gentle";
  });
  const [signingOut, setSigningOut] = useState(false);
  const [syncToken, setSyncToken] = useState<string | null>(null);
  const [tokenCopied, setTokenCopied] = useState(false);

  // Dynamic connector status
  const [hasBrowsingData, setHasBrowsingData] = useState(false);
  const [hasIOSData, setHasIOSData] = useState(false);
  const [connectorLoading, setConnectorLoading] = useState(true);

  // Account operation states
  const [showClearDialog, setShowClearDialog] = useState(false);
  const [clearConfirmText, setClearConfirmText] = useState("");
  const [clearing, setClearing] = useState(false);

  const [deleteStep, setDeleteStep] = useState(0); // 0=hidden, 1=warning, 2=email confirm, 3=final
  const [deleteEmailConfirm, setDeleteEmailConfirm] = useState("");
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data: { user } }) => {
      if (!user) return;

      setUserEmail(user.email ?? null);
      setDisplayName(
        user.user_metadata?.display_name ||
          user.email?.split("@")[0] ||
          "用户"
      );

      // Fetch sync token
      const { data: profile } = (await supabase
        .from("profiles")
        .select("sync_token")
        .eq("id", user.id)
        .single()) as { data: { sync_token: string } | null };

      if (profile?.sync_token) {
        setSyncToken(profile.sync_token);
      }

      // Check connector status
      const { count: browsingCount } = await supabase
        .from("browsing_sessions")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id);

      setHasBrowsingData((browsingCount || 0) > 0);

      const { count: iosCount } = await supabase
        .from("data_points")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id)
        .eq("source", "iphone");

      setHasIOSData((iosCount || 0) > 0);
      setConnectorLoading(false);
    });
  }, []);

  const handleSignOut = async () => {
    setSigningOut(true);
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/auth/login");
  };

  const handleClearData = async () => {
    if (clearConfirmText !== "删除") return;
    setClearing(true);
    try {
      const res = await fetch("/api/account/clear-data", { method: "POST" });
      if (res.ok) {
        setShowClearDialog(false);
        setClearConfirmText("");
        window.location.reload();
      }
    } finally {
      setClearing(false);
    }
  };

  const handleExportData = () => {
    window.open("/api/account/export", "_blank");
  };

  const handleDeleteAccount = async () => {
    setDeleting(true);
    try {
      // Auto-download export first
      window.open("/api/account/export", "_blank");
      // Then delete
      const res = await fetch("/api/account/delete", { method: "POST" });
      if (res.ok) {
        router.push("/auth/login");
      }
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div className="min-h-screen">
      {/* Header */}
      <div className="px-12 pt-12 pb-10">
        <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
          设置
        </h1>
        <p className="text-base text-muted-foreground mt-2">
          管理你的账户和偏好
        </p>
      </div>

      <div className="px-12 pb-12 space-y-8 max-w-3xl">
        {/* Account Section */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <User
              className="h-4 w-4 text-muted-foreground"
              strokeWidth={1.5}
            />
            <h2 className="font-display text-lg text-foreground">账户</h2>
          </div>

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div>
              <p className="text-sm text-foreground">邮箱</p>
              <p className="text-xs text-muted-foreground">
                {userEmail ?? "未登录"}
              </p>
            </div>
          </div>

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div>
              <p className="text-sm text-foreground">显示名称</p>
              <p className="text-xs text-muted-foreground">{displayName}</p>
            </div>
          </div>

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div>
              <p className="text-sm text-foreground">当前计划</p>
              <p className="text-xs text-muted-foreground">免费版</p>
            </div>
          </div>

          <div className="flex items-center justify-between py-3 last:border-0">
            <div>
              <p className="text-sm text-foreground">退出登录</p>
              <p className="text-xs text-muted-foreground">登出当前账户</p>
            </div>
            <button
              onClick={handleSignOut}
              disabled={signingOut}
              className="flex items-center gap-2 border border-border/50 text-muted-foreground rounded-full px-4 py-2 text-sm hover:text-foreground hover:border-border transition-colors disabled:opacity-50"
            >
              <LogOut className="h-4 w-4" strokeWidth={1.5} />
              {signingOut ? "退出中…" : "退出"}
            </button>
          </div>
        </div>

        {/* Data Sources Section */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Blocks
              className="h-4 w-4 text-muted-foreground"
              strokeWidth={1.5}
            />
            <h2 className="font-display text-lg text-foreground">数据源</h2>
          </div>

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div className="flex items-center gap-3">
              <Globe
                className="h-4 w-4 text-muted-foreground"
                strokeWidth={1.5}
              />
              <div>
                <p className="text-sm text-foreground">浏览器扩展</p>
                <p className="text-xs text-muted-foreground">
                  追踪浏览活动和屏幕时间
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {connectorLoading ? (
                <span className="text-xs text-muted-foreground">检查中...</span>
              ) : (
                <>
                  <div
                    className={`h-2 w-2 rounded-full ${hasBrowsingData ? "bg-emerald-500" : "bg-muted-foreground/30"}`}
                  />
                  <span
                    className={`text-xs ${hasBrowsingData ? "text-emerald-600 font-medium" : "text-muted-foreground"}`}
                  >
                    {hasBrowsingData ? "已连接" : "未连接"}
                  </span>
                </>
              )}
            </div>
          </div>

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

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div className="flex items-center gap-3">
              <Smartphone
                className="h-4 w-4 text-muted-foreground"
                strokeWidth={1.5}
              />
              <div>
                <p className="text-sm text-foreground">手机 App</p>
                <p className="text-xs text-muted-foreground">
                  同步健康和活动数据
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {connectorLoading ? (
                <span className="text-xs text-muted-foreground">检查中...</span>
              ) : (
                <>
                  <div
                    className={`h-2 w-2 rounded-full ${hasIOSData ? "bg-emerald-500" : "bg-muted-foreground/30"}`}
                  />
                  <span
                    className={`text-xs ${hasIOSData ? "text-emerald-600 font-medium" : "text-muted-foreground"}`}
                  >
                    {hasIOSData ? "已连接" : "未连接"}
                  </span>
                </>
              )}
            </div>
          </div>

          <div className="pt-3 last:border-0">
            <Link
              href="/dashboard/connectors"
              className="text-sm text-primary hover:opacity-80 transition-opacity"
            >
              管理所有连接器 →
            </Link>
          </div>
        </div>

        {/* Echo AI Section */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Bot
              className="h-4 w-4 text-muted-foreground"
              strokeWidth={1.5}
            />
            <h2 className="font-display text-lg text-foreground">Echo AI</h2>
          </div>

          <p className="text-sm text-muted-foreground mb-4">
            选择 Echo 的性格风格
          </p>

          <div className="space-y-2">
            {ECHO_PERSONALITIES.map((p) => {
              const isSelected = echoPersonality === p.id;
              return (
                <button
                  key={p.id}
                  onClick={() => {
                    setEchoPersonality(p.id);
                    localStorage.setItem("echo-personality", p.id);
                  }}
                  className={`w-full flex items-center gap-4 rounded-xl border p-4 text-left transition-all duration-200 ${
                    isSelected
                      ? "border-primary/60 bg-primary/5"
                      : "border-border/40 bg-background hover:border-border hover:shadow-sm"
                  }`}
                >
                  <div
                    className={`h-4 w-4 rounded-full border-2 flex items-center justify-center transition-colors ${
                      isSelected
                        ? "border-primary"
                        : "border-muted-foreground/40"
                    }`}
                  >
                    {isSelected && (
                      <div className="h-2 w-2 rounded-full bg-primary" />
                    )}
                  </div>
                  <div>
                    <p className="text-sm text-foreground">{p.label}</p>
                    <p className="text-xs text-muted-foreground">
                      {p.description}
                    </p>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Privacy Section */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Shield
              className="h-4 w-4 text-muted-foreground"
              strokeWidth={1.5}
            />
            <h2 className="font-display text-lg text-foreground">隐私</h2>
          </div>

          <div className="py-3 border-b border-border/30">
            <p className="text-sm text-foreground mb-1">数据说明</p>
            <p className="text-xs text-muted-foreground leading-relaxed">
              所有数据仅存储在你的设备和你的 Supabase 账户中。ToDay
              不会将你的个人数据分享给任何第三方。你可以随时导出或删除所有数据。
            </p>
          </div>

          <div className="flex items-center justify-between py-3">
            <div>
              <p className="text-sm text-foreground">导出数据</p>
              <p className="text-xs text-muted-foreground">
                下载你的所有数据（JSON 格式）
              </p>
            </div>
            <button
              onClick={handleExportData}
              className="flex items-center gap-2 border border-border/50 text-muted-foreground rounded-full px-4 py-2 text-sm hover:text-foreground hover:border-border transition-colors"
            >
              <Download className="h-4 w-4" strokeWidth={1.5} />
              导出
            </button>
          </div>
        </div>

        {/* Danger Zone */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <AlertTriangle
              className="h-4 w-4 text-muted-foreground"
              strokeWidth={1.5}
            />
            <h2 className="font-display text-lg text-foreground">危险区域</h2>
          </div>

          {/* Clear Data */}
          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div>
              <p className="text-sm text-foreground">清除所有数据</p>
              <p className="text-xs text-muted-foreground">
                删除所有记录，账户本身保留
              </p>
            </div>
            <button
              onClick={() => setShowClearDialog(true)}
              className="border border-destructive/30 text-destructive rounded-lg px-4 py-2 text-sm font-medium hover:bg-destructive/10 transition-colors"
            >
              清除数据
            </button>
          </div>

          {/* Clear Data Dialog */}
          {showClearDialog && (
            <div className="py-3 border-b border-border/30 bg-destructive/5 rounded-lg px-4 -mx-2">
              <p className="text-sm text-foreground mb-2">
                此操作将清除你的所有浏览记录、健康数据和心情记录。
              </p>
              <p className="text-xs text-muted-foreground mb-3">
                请输入「删除」以确认：
              </p>
              <div className="flex gap-2">
                <input
                  type="text"
                  value={clearConfirmText}
                  onChange={(e) => setClearConfirmText(e.target.value)}
                  placeholder="删除"
                  className="flex-1 rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-destructive/20"
                />
                <button
                  onClick={handleClearData}
                  disabled={clearConfirmText !== "删除" || clearing}
                  className="rounded-lg bg-destructive text-destructive-foreground px-4 py-2 text-sm font-medium disabled:opacity-50"
                >
                  {clearing ? "清除中..." : "确认清除"}
                </button>
                <button
                  onClick={() => {
                    setShowClearDialog(false);
                    setClearConfirmText("");
                  }}
                  className="rounded-lg border border-border px-4 py-2 text-sm text-muted-foreground hover:text-foreground"
                >
                  取消
                </button>
              </div>
            </div>
          )}

          {/* Delete Account */}
          <div className="flex items-center justify-between py-3 last:border-0">
            <div>
              <p className="text-sm text-foreground">删除账户</p>
              <p className="text-xs text-muted-foreground">
                永久删除你的账户和所有相关数据（30 天冷却期）
              </p>
            </div>
            <button
              onClick={() => setDeleteStep(1)}
              className="border border-destructive/30 text-destructive rounded-lg px-4 py-2 text-sm font-medium hover:bg-destructive/10 transition-colors"
            >
              删除账户
            </button>
          </div>

          {/* Delete Account Step 1: Warning */}
          {deleteStep === 1 && (
            <div className="py-3 bg-destructive/5 rounded-lg px-4 -mx-2">
              <p className="text-sm text-foreground mb-2 font-medium">
                确定要删除账户吗？
              </p>
              <p className="text-xs text-muted-foreground mb-3">
                删除后有 30 天冷却期，期间登录可撤销。到期后账户和所有数据将被永久删除。
                我们会先导出你的数据。
              </p>
              <div className="flex gap-2">
                <button
                  onClick={() => setDeleteStep(2)}
                  className="rounded-lg bg-destructive text-destructive-foreground px-4 py-2 text-sm font-medium"
                >
                  继续
                </button>
                <button
                  onClick={() => setDeleteStep(0)}
                  className="rounded-lg border border-border px-4 py-2 text-sm text-muted-foreground hover:text-foreground"
                >
                  取消
                </button>
              </div>
            </div>
          )}

          {/* Delete Account Step 2: Email Confirm */}
          {deleteStep === 2 && (
            <div className="py-3 bg-destructive/5 rounded-lg px-4 -mx-2">
              <p className="text-sm text-foreground mb-2">
                请输入你的邮箱以确认：
              </p>
              <div className="flex gap-2">
                <input
                  type="email"
                  value={deleteEmailConfirm}
                  onChange={(e) => setDeleteEmailConfirm(e.target.value)}
                  placeholder={userEmail || "your@email.com"}
                  className="flex-1 rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-destructive/20"
                />
                <button
                  onClick={() => {
                    if (deleteEmailConfirm === userEmail) setDeleteStep(3);
                  }}
                  disabled={deleteEmailConfirm !== userEmail}
                  className="rounded-lg bg-destructive text-destructive-foreground px-4 py-2 text-sm font-medium disabled:opacity-50"
                >
                  确认
                </button>
                <button
                  onClick={() => {
                    setDeleteStep(0);
                    setDeleteEmailConfirm("");
                  }}
                  className="rounded-lg border border-border px-4 py-2 text-sm text-muted-foreground hover:text-foreground"
                >
                  取消
                </button>
              </div>
            </div>
          )}

          {/* Delete Account Step 3: Final */}
          {deleteStep === 3 && (
            <div className="py-3 bg-destructive/5 rounded-lg px-4 -mx-2">
              <p className="text-sm text-foreground mb-2 font-medium">
                最后确认
              </p>
              <p className="text-xs text-muted-foreground mb-3">
                点击确认后，你的数据将被导出下载，账户将进入 30 天删除倒计时。
              </p>
              <div className="flex gap-2">
                <button
                  onClick={handleDeleteAccount}
                  disabled={deleting}
                  className="rounded-lg bg-destructive text-destructive-foreground px-4 py-2 text-sm font-medium disabled:opacity-50"
                >
                  {deleting ? "处理中..." : "确认删除"}
                </button>
                <button
                  onClick={() => {
                    setDeleteStep(0);
                    setDeleteEmailConfirm("");
                  }}
                  className="rounded-lg border border-border px-4 py-2 text-sm text-muted-foreground hover:text-foreground"
                >
                  取消
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="text-center pb-4">
          <p className="text-xs text-muted-foreground">ToDay v0.5.0</p>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 5: Build to verify**

Run: `cd /Users/looanli/Projects/ToDay/web && npx next build 2>&1 | tail -30`

- [ ] **Step 6: Commit**

```bash
cd /Users/looanli/Projects/ToDay && git add web/src/app/api/account/ web/src/app/dashboard/settings/page.tsx
git commit -m "feat: GDPR-grade account operations — clear data, delete account, data export"
```

---

### Task 8: Mood/Capture page — Supabase persistence

**Files:**
- Modify: `src/app/dashboard/mood/page.tsx`

Note: The `mood_records` table has columns `emoji TEXT NOT NULL, name TEXT NOT NULL, note TEXT`. We'll use `emoji="📝"`, `name="捕捉"`, `note=content` for capture memos.

- [ ] **Step 1: Rewrite mood/page.tsx with Supabase persistence**

Replace the entire file:

```typescript
"use client";

import { useState, useEffect } from "react";
import { cn } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";

interface Memo {
  id: string;
  content: string;
  createdAt: Date;
}

function groupByDate(memos: Memo[]): { label: string; memos: Memo[] }[] {
  const groups: Record<string, Memo[]> = {};
  const today = new Date().toDateString();
  const yesterday = new Date(Date.now() - 86400000).toDateString();

  for (const memo of memos) {
    const dateStr = new Date(memo.createdAt).toDateString();
    let label: string;
    if (dateStr === today) label = "今天";
    else if (dateStr === yesterday) label = "昨天";
    else
      label = new Date(memo.createdAt).toLocaleDateString("zh-CN", {
        month: "long",
        day: "numeric",
      });

    if (!groups[label]) groups[label] = [];
    groups[label].push(memo);
  }

  return Object.entries(groups).map(([label, memos]) => ({
    label,
    memos: memos.sort(
      (a, b) => b.createdAt.getTime() - a.createdAt.getTime()
    ),
  }));
}

function formatTime(date: Date): string {
  return date.toLocaleTimeString("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

function formatHeaderDate(): string {
  const now = new Date();
  return now.toLocaleDateString("zh-CN", {
    month: "numeric",
    day: "numeric",
  });
}

export default function CapturePage() {
  const [memos, setMemos] = useState<Memo[]>([]);
  const [inputValue, setInputValue] = useState("");
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data: { user } }) => {
      if (!user) {
        setLoading(false);
        return;
      }

      const { data } = await supabase
        .from("mood_records")
        .select("id, note, created_at")
        .eq("user_id", user.id)
        .eq("emoji", "📝")
        .eq("name", "捕捉")
        .order("created_at", { ascending: false })
        .limit(200);

      if (data) {
        setMemos(
          data
            .filter((r) => r.note)
            .map((r) => ({
              id: r.id,
              content: r.note!,
              createdAt: new Date(r.created_at),
            }))
        );
      }
      setLoading(false);
    });
  }, []);

  const grouped = groupByDate(memos);

  async function handleSubmit() {
    if (!inputValue.trim() || submitting) return;
    setSubmitting(true);

    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      setSubmitting(false);
      return;
    }

    const { data, error } = await supabase
      .from("mood_records")
      .insert({
        user_id: user.id,
        emoji: "📝",
        name: "捕捉",
        note: inputValue.trim(),
      })
      .select("id, created_at")
      .single();

    if (!error && data) {
      const newMemo: Memo = {
        id: data.id,
        content: inputValue.trim(),
        createdAt: new Date(data.created_at),
      };
      setMemos((prev) => [newMemo, ...prev]);
      setInputValue("");
    }
    setSubmitting(false);
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  }

  return (
    <div className="min-h-screen">
      {/* Header */}
      <div className="px-12 pt-12 pb-10 flex items-baseline justify-between">
        <div>
          <h1 className="font-display text-2xl font-normal tracking-tight text-foreground">
            捕捉
          </h1>
          <p className="text-sm text-muted-foreground mt-2">
            随时记录灵感、想法和此刻的心情
          </p>
        </div>
        <span className="text-sm text-muted-foreground">
          {formatHeaderDate()}
        </span>
      </div>

      <div className="px-12 pb-12 space-y-8">
        {/* Input Card */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <textarea
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="写点什么..."
            rows={3}
            className="w-full bg-transparent text-sm text-foreground placeholder:text-muted-foreground/50 outline-none resize-none"
          />
          <div className="flex justify-end mt-3">
            <button
              onClick={handleSubmit}
              disabled={!inputValue.trim() || submitting}
              className={cn(
                "text-sm font-medium transition-opacity",
                inputValue.trim() && !submitting
                  ? "text-primary hover:opacity-80"
                  : "text-muted-foreground/40 cursor-default"
              )}
            >
              {submitting ? "保存中..." : "记录 ↵"}
            </button>
          </div>
        </div>

        {/* Loading State */}
        {loading && (
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div
                key={i}
                className="border border-border/40 bg-card rounded-xl px-5 py-4 animate-pulse"
              >
                <div className="h-4 bg-muted rounded w-3/4 mb-2" />
                <div className="h-3 bg-muted rounded w-16 ml-auto" />
              </div>
            ))}
          </div>
        )}

        {/* Memo Stream */}
        {!loading && (
          <div className="space-y-6">
            {grouped.map((group) => (
              <div key={group.label}>
                <p className="text-xs font-medium text-muted-foreground mb-3 mt-2">
                  {group.label}
                </p>
                <div className="space-y-3">
                  {group.memos.map((memo) => (
                    <div
                      key={memo.id}
                      className="border border-border/40 bg-card rounded-xl px-5 py-4 hover:shadow-sm transition-shadow"
                    >
                      <p className="text-sm text-foreground whitespace-pre-wrap">
                        {memo.content}
                      </p>
                      <p className="text-[11px] text-muted-foreground font-mono text-right mt-2">
                        {formatTime(memo.createdAt)}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/looanli/Projects/ToDay && git add web/src/app/dashboard/mood/page.tsx
git commit -m "feat: migrate capture/mood to Supabase persistence, remove localStorage"
```

---

### Task 9: Timeline stats — real calculation

**Files:**
- Modify: `src/app/dashboard/timeline/page.tsx`

- [ ] **Step 1: Update timeline page**

Two changes needed:
1. Replace hardcoded `stats` array with computed values from `browsingSessions`
2. Fix `fetchBrowsingSessions` to use Authorization header instead of `?token=` query param

In `src/app/dashboard/timeline/page.tsx`:

**Change 1:** Replace the `fetchBrowsingSessions` function (lines 80-123) — use Authorization header:

```typescript
async function fetchBrowsingSessions(date: string): Promise<BrowsingSession[]> {
  try {
    const { createClient } = await import("@/lib/supabase/client");
    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return [];

    const { data: profile } = await supabase
      .from("profiles")
      .select("sync_token")
      .eq("id", user.id)
      .single() as { data: { sync_token: string } | null };

    if (!profile?.sync_token) return [];

    const res = await fetch(`/api/screen-time?date=${date}`, {
      headers: { Authorization: `Bearer ${profile.sync_token}` },
    });
    if (!res.ok) return [];
    const json = await res.json();

    const sessions: BrowsingSession[] = [];
    if (json.today?.topSites) {
      for (const site of json.today.topSites) {
        if (site.minutes > 0) {
          sessions.push({
            domain: site.domain,
            label: site.domain,
            category: site.title || site.domain,
            title: site.title || site.domain,
            startTime: 0,
            endTime: 0,
            duration: site.minutes * 60,
          });
        }
      }
    }

    return sessions;
  } catch {
    return [];
  }
}
```

**Change 2:** Replace the hardcoded `stats` constant (lines 56-61) and make the stats bar dynamic. Remove the `const stats = [...]` block and replace the Stats Bar section (lines 356-375) with computed stats:

Remove lines 56-61 (the hardcoded stats constant).

Replace the Stats Bar section with:

```tsx
        {/* Stats Bar */}
        {events.length > 0 && (
          <div className="border border-border/40 bg-card rounded-xl p-6">
            <p className="text-xs font-medium text-muted-foreground mb-4">
              今日统计
            </p>
            <div className="grid grid-cols-3 gap-4">
              <div className="text-center">
                <p className="font-display text-lg text-foreground">
                  {browsingSessions.length > 0
                    ? formatDuration(
                        browsingSessions.reduce((sum, s) => sum + s.duration, 0)
                      )
                    : "--"}
                </p>
                <p className="text-xs text-muted-foreground mt-1">屏幕时间</p>
              </div>
              <div className="text-center">
                <p className="font-display text-lg text-foreground">
                  {browsingSessions.length > 0
                    ? new Set(browsingSessions.map((s) => s.domain)).size
                    : "--"}
                </p>
                <p className="text-xs text-muted-foreground mt-1">访问站点</p>
              </div>
              <div className="text-center">
                <p className="font-display text-lg text-foreground">
                  {browsingSessions.length > 0
                    ? (() => {
                        const catMap = new Map<string, number>();
                        for (const s of browsingSessions) {
                          catMap.set(
                            s.category,
                            (catMap.get(s.category) || 0) + s.duration
                          );
                        }
                        return Array.from(catMap.entries()).sort(
                          (a, b) => b[1] - a[1]
                        )[0]?.[0] || "--";
                      })()
                    : "--"}
                </p>
                <p className="text-xs text-muted-foreground mt-1">最活跃</p>
              </div>
            </div>
          </div>
        )}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/looanli/Projects/ToDay && git add web/src/app/dashboard/timeline/page.tsx
git commit -m "feat: compute real timeline stats, use auth header instead of query param"
```

---

### Task 10: Extension manifest cleanup

**Files:**
- Modify: `extension/manifest.json`

- [ ] **Step 1: Remove localhost from host_permissions**

In `extension/manifest.json`, replace lines 13-16:

Old:
```json
  "host_permissions": [
    "http://localhost:3001/*",
    "https://to-day-ten.vercel.app/*"
  ],
```

New:
```json
  "host_permissions": [
    "https://to-day-ten.vercel.app/*"
  ],
```

- [ ] **Step 2: Commit**

```bash
cd /Users/looanli/Projects/ToDay && git add extension/manifest.json
git commit -m "chore: remove localhost from extension host_permissions"
```

---

### Task 11: Final build verification

- [ ] **Step 1: Run full build**

Run: `cd /Users/looanli/Projects/ToDay/web && npx next build 2>&1 | tail -40`

Expected: Build succeeds with zero errors.

- [ ] **Step 2: Verify all routes are listed**

Check that the build output lists all API routes:
- `/api/account/clear-data`
- `/api/account/delete`
- `/api/account/export`
- `/api/dashboard`
- `/api/data`
- `/api/echo/chat`
- `/api/echo/insight`
- `/api/screen-time`
- `/api/sessions`

And that `proxy.ts` is picked up.

- [ ] **Step 3: Manual checklist for user**

Print this checklist for the user to complete:
1. Run migration `003_soft_delete.sql` in Supabase SQL Editor
2. Add `DEEPSEEK_API_KEY` to Vercel environment variables
3. Configure Resend SMTP in Supabase Dashboard (Authentication > SMTP Settings)
4. Redeploy on Vercel
5. Test: visit `/dashboard` without login → should redirect to `/auth/login`
6. Test: register new account → should redirect to `/auth/verify`
7. Test: call `/api/echo/chat` without auth → should get 401
8. Test: settings page shows dynamic connector status
9. Test: capture page saves to Supabase (check `mood_records` table)
10. Test: clear data + delete account buttons work
