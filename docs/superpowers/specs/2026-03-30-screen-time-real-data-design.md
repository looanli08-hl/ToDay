# Screen Time Real Data Integration

**Date:** 2026-03-30
**Scope:** Replace mock data on web dashboard screen time page with real browser extension data, using production-grade architecture.

## Goal

Wire the screen time page to display real browsing data from the browser extension, with a normalized relational storage model that supports SQL aggregation and scales to 100k+ users.

## Architecture Overview

```
Browser Extension (incremental sync)
  → POST /api/sessions (deduplicate + insert)
  → Supabase: browsing_sessions table (1 row per session)

Screen Time Page
  → GET /api/screen-time?date=YYYY-MM-DD
  → Server-side SQL aggregation
  → Render aggregated results
```

## Database: `browsing_sessions` Table

New Supabase table replacing the JSONB blob pattern in `data_points`.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID (PK) | Default gen_random_uuid() |
| user_id | UUID FK | → profiles(id), NOT NULL |
| domain | TEXT | e.g. "github.com", NOT NULL |
| label | TEXT | e.g. "GitHub" |
| category | TEXT | e.g. "效率", NOT NULL |
| title | TEXT | Last page title visited |
| start_time | TIMESTAMPTZ | Session start, NOT NULL |
| end_time | TIMESTAMPTZ | Session end, NOT NULL |
| duration_seconds | INT | Precomputed duration, NOT NULL |
| source | TEXT | "browser-extension" / "ios" / "desktop", DEFAULT 'browser-extension' |
| created_at | TIMESTAMPTZ | DEFAULT now() |

**Indexes:**
- `(user_id, start_time)` — all time-range queries
- `(user_id, category, start_time)` — category aggregation

**Unique constraint:**
- `(user_id, domain, start_time)` — prevents duplicate session insertion

**RLS policy:**
- SELECT/INSERT/UPDATE/DELETE: `user_id = auth.uid()`

## API: `POST /api/sessions`

Receives incremental session data from the browser extension.

**Request:**
```json
{
  "sessions": [
    {
      "domain": "github.com",
      "label": "GitHub",
      "category": "效率",
      "title": "Pull Requests - ToDay",
      "startTime": 1711800000000,
      "endTime": 1711800600000,
      "duration": 600
    }
  ]
}
```

**Logic:**
1. Authenticate user via Supabase session (required — no anonymous fallback)
2. Map each session to a `browsing_sessions` row:
   - Convert `startTime`/`endTime` from epoch ms to ISO timestamps
   - `duration` (seconds) → `duration_seconds`
3. Bulk UPSERT with `ON CONFLICT (user_id, domain, start_time) DO NOTHING`
4. Return `{ inserted: number, duplicates: number }`

**Error responses:**
- 401: Not authenticated
- 400: Missing/invalid sessions array

## API: `GET /api/screen-time`

Server-side aggregation endpoint for the screen time page.

**Query params:**
- `date` (optional): YYYY-MM-DD, defaults to today

**Response:**
```json
{
  "today": {
    "totalMinutes": 272,
    "categories": [
      { "name": "效率", "minutes": 135 },
      { "name": "娱乐", "minutes": 70 }
    ],
    "topSites": [
      { "domain": "github.com", "title": "Pull Requests", "minutes": 80 }
    ],
    "hourly": [0, 0, 0, 0, 0, 0, 2, 8, 15, 28, 35, 20, 10, 18, 32, 22, 12, 8, 5, 15, 30, 18, 6, 0]
  },
  "yesterday": {
    "totalMinutes": 310
  },
  "weekly": [
    { "day": "一", "date": "2026-03-24", "minutes": 280 },
    { "day": "二", "date": "2026-03-25", "minutes": 310 }
  ]
}
```

**SQL queries (all filtered by `user_id = auth.uid()`):**

1. **Today total:** `SUM(duration_seconds)/60` WHERE start_time in target date
2. **Categories:** `GROUP BY category`, `SUM(duration_seconds)/60`, ORDER BY minutes DESC
3. **Top sites:** `GROUP BY domain`, pick MAX(title), `SUM(duration_seconds)/60`, ORDER BY minutes DESC, LIMIT 10
4. **Hourly:** `EXTRACT(HOUR FROM start_time AT TIME ZONE 'Asia/Shanghai')`, `GROUP BY hour`, `SUM(duration_seconds)/60`, fill missing hours with 0. Timezone from client `?tz=Asia/Shanghai` param, defaults to Asia/Shanghai.
5. **Yesterday:** Same as #1 for date - 1 day
6. **Weekly:** Loop 7 days, SUM per day (or single query with `GROUP BY DATE(start_time)`)

**Error responses:**
- 401: Not authenticated
- Returns zero-filled response when no data (not an error)

## Extension Authentication

The extension needs to identify which user's data it's syncing. Approach: **sync token**.

1. User logs into web dashboard
2. Dashboard settings page shows a "Sync Token" (a UUID stored in `profiles.sync_token` column)
3. User copies token into extension popup's settings field
4. Extension stores token in `chrome.storage.local`
5. Extension sends token as `Authorization: Bearer <sync_token>` header

**API validation:** `POST /api/sessions` looks up the sync_token in `profiles` table to get `user_id`. No Supabase session cookie needed.

**DB change:** Add `sync_token UUID DEFAULT gen_random_uuid()` column to `profiles` table.

**Fallback:** If no token configured, extension still tracks locally (chrome.storage) but does not sync. Popup shows "请在设置中输入同步令牌" prompt.

## Browser Extension Changes

File: `extension/src/background.js`

1. **New state field:** `lastSyncedCount` — tracks how many sessions have been synced
2. **Incremental sync:** `syncToServer()` sends only `sessions.slice(lastSyncedCount)`
3. **API_URL:** Configurable `API_BASE_URL`, defaulting to the Vercel deployment URL. Endpoint: `${API_BASE_URL}/api/sessions`
4. **On success:** Update `lastSyncedCount = sessions.length`
5. **On failure:** Don't update count → retry next cycle
6. **Auth header:** Read sync token from `chrome.storage.local`, send as `Authorization: Bearer <token>`
7. **No token:** Skip sync, log warning, data stays local

**Backwards compatibility:** Keep local `chrome.storage` session cache unchanged. The extension still works offline; it just syncs when the server is available.

File: `extension/src/popup.html` + `extension/src/popup.js`

- Add settings section: API base URL input + sync token input
- "Save" persists to `chrome.storage.local`
- Show sync status: "已连接" / "未连接 — 请输入同步令牌"

## Frontend: Screen Time Page

File: `web/src/app/dashboard/screen-time/page.tsx`

**Changes:**
1. Remove all mock data constants (`todaySummary`, `categories`, `topSites`, `hourlyData`, `weeklyData`)
2. Add data fetching with `useEffect` + `fetch('/api/screen-time?date=...')`
3. Add three states: loading (skeleton), empty (no data message), loaded (current layout)
4. Keep all existing layout, styling, and components unchanged
5. Wire fetched data to existing rendering logic

**Empty state:** Simple centered message: "还没有浏览数据" with subtitle "安装浏览器扩展开始记录你的屏幕时间"

**Loading state:** Skeleton cards matching current layout dimensions

## What's NOT Changing

- `/api/data` endpoint — stays as-is, timeline page still uses it
- `data_points` table — no migration/deletion, other features depend on it
- Page layout and visual design — deferred to separate redesign task
- iOS data sync — separate future task
- Echo integration — separate future task

## Migration Notes

- Create `browsing_sessions` table via Supabase SQL editor (no migration framework yet)
- Add `sync_token` column to `profiles` table via Supabase SQL editor
- Existing data in `data_points` can be backfilled later if needed, not blocking
- Extension update can be pushed independently of web deployment
- SQL scripts saved in `web/src/lib/supabase/` alongside existing `schema.sql`
