# Dashboard Real Data Integration

## Context

The web dashboard currently shows hardcoded placeholder data ("--" stat cards, mock timeline events). All actual user data already exists in Supabase — pushed by the iOS app (health, mood, location via `data_points` table) and the browser extension (browsing sessions via `browsing_sessions` table). The dashboard just needs to read and display it.

## Goal

Make the web dashboard show real user data from all sources, so first-time users see meaningful content after connecting their devices.

## Architecture

Supabase is the central data hub. Each client writes its own data, every client reads all data.

```
iOS App ──writes──→ Supabase ←──writes── Browser Extension
                      ↓
              Web Dashboard reads all
```

## API: GET /api/dashboard

New endpoint that aggregates today's data for the authenticated user.

**Auth:** Accepts sync_token via Authorization header (same pattern as /api/screen-time).

**Response:**

```json
{
  "stats": {
    "steps": 8432,
    "active_minutes": 45,
    "sleep_hours": 7.2,
    "screen_time_minutes": 185,
    "mood_latest": "happy",
    "mood_count": 2
  },
  "timeline": [
    { "time": "07:30", "type": "sleep", "label": "睡眠结束 · 7.2小时" },
    { "time": "09:15", "type": "activity", "label": "步行 · 3,200 步" },
    { "time": "10:00", "type": "screen", "label": "屏幕时间 · 效率工具 45m" },
    { "time": "12:30", "type": "mood", "label": "记录心情 · 开心" }
  ]
}
```

**Data sources:**

| Stat | Table | Query |
|------|-------|-------|
| Steps | `data_points` | type='steps', today, sum values |
| Active minutes | `data_points` | type='workout' or 'activeEnergy', today |
| Sleep hours | `data_points` | type='sleep', last night (yesterday 20:00 - today 12:00) |
| Screen time | `browsing_sessions` | today, sum duration_seconds |
| Mood | `mood_records` | today, latest emoji + count |

**Timeline construction:**
1. Query all data_points for today (type in steps, sleep, workout, heartRate)
2. Query all browsing_sessions for today, group by hour + category
3. Query all mood_records for today
4. Merge all events, sort by timestamp descending
5. Format each event as { time, type, label }
6. Return most recent 20 events

## Dashboard Page Changes

**File:** `web/src/app/dashboard/page.tsx`

Already converted to client component. Changes needed:

1. On mount, call `/api/dashboard` with user's sync token
2. Replace hardcoded stat card values with API response
3. Replace hardcoded timeline with real events
4. Add loading state while fetching
5. Add empty state when no data exists

**Stat cards mapping:**

| Card | Data field | Display |
|------|-----------|---------|
| 活动时间 | stats.steps + stats.active_minutes | "8,432 步" or "45 分钟" |
| 睡眠 | stats.sleep_hours | "7.2 小时" |
| 屏幕时间 | stats.screen_time_minutes | "3h 5m" |
| 心情 | stats.mood_latest + stats.mood_count | emoji + "2 条记录" |

**Empty state:**
When stats are all zero/null, show a card:
"连接你的设备开始记录 — 安装浏览器扩展或下载 iOS App"
With links to the browser extension and App Store.

**Loading state:**
Stat cards show subtle skeleton/pulse animation while loading.

## Sync Token Retrieval

Dashboard needs the user's sync token to call the API. The settings page already fetches it from the `profiles` table. Dashboard should do the same:

```ts
const { data } = await supabase.from('profiles').select('sync_token').eq('id', user.id).single();
```

Then pass it to `/api/dashboard?token={sync_token}` or via Authorization header.

## Non-Goals

- Echo card: keep current static message (separate effort)
- Weekly activity chart: keep static (needs 7 days of data to be meaningful)
- iOS app reading browsing data (step 2, not now)
- Real-time updates / WebSocket (step 3, not now)

## File Changes

| File | Action |
|------|--------|
| `web/src/app/api/dashboard/route.ts` | Create — aggregation API |
| `web/src/app/dashboard/page.tsx` | Modify — fetch and display real data |
