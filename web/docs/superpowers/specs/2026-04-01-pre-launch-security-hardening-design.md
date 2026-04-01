# Pre-Launch Security Hardening & Quality Fixes

Date: 2026-04-01
Status: Approved
Scope: 11 issues — 6 critical security, 5 quality

---

## 1. DeepSeek API Key — Environment Variable

### Current state
DeepSeek API key hardcoded in plaintext in:
- `src/app/api/echo/insight/route.ts:1`
- `src/app/api/echo/chat/route.ts:1`

### Change
- Delete hardcoded constant from both files
- Read `process.env.DEEPSEEK_API_KEY` (no `NEXT_PUBLIC_` prefix — server-only)
- If missing, return `503 Service Unavailable` with `{ error: "AI service not configured" }`
- Add to `.env.local` for local dev
- Add to Vercel environment variables (user does this manually)

### Files
- `src/app/api/echo/insight/route.ts`
- `src/app/api/echo/chat/route.ts`
- `.env.local`

---

## 2. Unified Auth Layer (`withAuth`)

### Current state
Each API route implements its own auth logic. Some accept `?token=` query params. `/api/data` has an unauthenticated in-memory store. `/api/echo/*` has zero auth.

### Design

Create `src/lib/api/auth.ts` exporting:

```typescript
type AuthenticatedHandler = (
  req: NextRequest,
  context: { userId: string }
) => Promise<Response>;

function withAuth(handler: AuthenticatedHandler): (req: NextRequest) => Promise<Response>
```

Auth resolution order:
1. `Authorization: Bearer <token>` header → RPC `get_user_id_by_sync_token(token)` → userId
2. Supabase SSR cookie session → `getUser()` → userId
3. Neither → `401 { error: "Authentication required" }`

No query param auth. No anonymous fallback. No in-memory store.

### Migration per route

| Route | Before | After |
|-------|--------|-------|
| `/api/echo/chat` | No auth | `withAuth` |
| `/api/echo/insight` | No auth | `withAuth` |
| `/api/sessions` | Custom Bearer check | `withAuth` |
| `/api/screen-time` | `resolveUserId()` + query param | `withAuth` |
| `/api/dashboard` | `resolveUserId()` + query param | `withAuth` |
| `/api/data` | Optional session + memoryStore | `withAuth` |

### Removals
- Delete `memoryStore` array and all memory-related logic from `/api/data/route.ts`
- Delete `resolveUserId()` from `screen-time/route.ts` and `dashboard/route.ts`
- Delete all `searchParams.get("token")` paths

### Files
- `src/lib/api/auth.ts` (new)
- `src/app/api/echo/chat/route.ts`
- `src/app/api/echo/insight/route.ts`
- `src/app/api/sessions/route.ts`
- `src/app/api/screen-time/route.ts`
- `src/app/api/dashboard/route.ts`
- `src/app/api/data/route.ts`

---

## 3. Dashboard Middleware

### Current state
No `middleware.ts`. Dashboard pages render without session check.

### Design

Create `src/middleware.ts`:
- Match `/dashboard/:path*`
- Create Supabase SSR client, call `getUser()`
- No user → `redirect('/auth/login')`
- Has user → `next()`, also refresh session cookie
- Exclude from matching: `/auth/*`, `/api/*`, `/`, static assets

### Config
```typescript
export const config = {
  matcher: ['/dashboard/:path*'],
};
```

### Files
- `src/middleware.ts` (new)

---

## 4. Email Verification — Resend SMTP

### Current state
Registration bypasses email verification. `TODO` comment in `register/page.tsx:44`. Supabase built-in SMTP limited to 4/hour.

### Design

**Supabase config (manual, in Supabase Dashboard):**
- Authentication > SMTP Settings > Enable Custom SMTP
- Host: `smtp.resend.com`, Port: 465, User: `resend`, Pass: Resend API key
- Sender: `noreply@daycho.com` (or configured domain)

**Code changes:**
- `register/page.tsx`: Restore redirect to `/auth/verify?email=...` after signup
- `login/page.tsx`: Check if login error is "Email not confirmed" → show resend link + message
- `verify/page.tsx`: Already implemented, just needs to be reachable again

### Files
- `src/app/auth/register/page.tsx`
- `src/app/auth/login/page.tsx` (ensure resend flow works)

---

## 5. Mood/Capture — Supabase Persistence

### Current state
`mood/page.tsx` reads/writes `localStorage` only. Supabase `mood_records` table already exists in schema.

### Design

Table structure (already exists):
```sql
mood_records (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES profiles(id),
  content TEXT,
  mood_score INTEGER,
  created_at TIMESTAMPTZ
)
```

Page changes:
- On mount: fetch `mood_records` for current user, ordered by `created_at DESC`
- On submit: insert into `mood_records` via Supabase client
- Remove all `localStorage` read/write for memos
- Add loading skeleton on initial fetch
- Add error state if fetch/insert fails

### Files
- `src/app/dashboard/mood/page.tsx`

---

## 6. Account Operations — GDPR-Grade

### Database migration

Add `deleted_at TIMESTAMPTZ DEFAULT NULL` to:
- `profiles`
- `data_points`
- `browsing_sessions`
- `mood_records`

Update RLS SELECT policies: add `AND deleted_at IS NULL` condition.

### New API routes

**`POST /api/account/clear-data`**
- `withAuth` protected
- Sets `deleted_at = NOW()` on user's `data_points`, `browsing_sessions`, `mood_records`
- Returns `{ cleared: true }`

**`POST /api/account/delete`**
- `withAuth` protected
- Sets `profiles.deleted_at = NOW()`
- Signs out user (revoke session)
- Returns `{ deleted: true, grace_period_days: 30 }`
- During 30-day window: login shows "account scheduled for deletion" with cancel option

**`GET /api/account/export`**
- `withAuth` protected
- Queries all user data: profile, mood_records, browsing_sessions, data_points
- Returns JSON blob with all data
- Content-Disposition: attachment (triggers download)

### Settings page UI

**Clear data button:**
- Click → confirmation dialog with text input (type "删除" to confirm)
- On confirm → call `/api/account/clear-data`
- Success → toast notification

**Delete account button:**
- Click → step 1: warning about 30-day deletion + data export prompt
- Step 2: input email to confirm
- Step 3: final confirmation
- On confirm → call `/api/account/export` (auto-download) then `/api/account/delete`
- Success → redirect to `/auth/login`

### Files
- `src/lib/supabase/migrations/003_soft_delete.sql` (new)
- `src/app/api/account/clear-data/route.ts` (new)
- `src/app/api/account/delete/route.ts` (new)
- `src/app/api/account/export/route.ts` (new)
- `src/app/dashboard/settings/page.tsx`

---

## 7. Timeline Stats — Real Calculation

### Current state
Stats bar shows hardcoded "--" for all values.

### Design
Calculate from the already-fetched browsing sessions:
- **Total duration**: sum of all session durations for selected date
- **Sites visited**: count of unique domains
- **Top category**: most time-spent category

Replace hardcoded "--" with computed values. Show "--" only when no data.

### Files
- `src/app/dashboard/timeline/page.tsx`

---

## 8. Connector Status — Dynamic

### Current state
Settings page shows static "未连接" labels.

### Design
Reuse the pattern from connectors page:
- Query `browsing_sessions` count for user (browser extension status)
- Query `data_points` with `source='iphone'` count (iOS app status)
- Show "已连接" with last sync timestamp, or "未连接"

### Files
- `src/app/dashboard/settings/page.tsx`

---

## 9. Extension Cleanup

### Current state
`manifest.json` `host_permissions` includes `http://localhost:3001/*`.

### Change
Remove localhost entry. Production only:
```json
"host_permissions": [
  "https://to-day-ten.vercel.app/*"
]
```

### Files
- `extension/manifest.json`

---

## Implementation Order

Dependencies determine order:

1. **Auth layer** (`withAuth`) — everything else depends on this
2. **API key env var** — quick, unblocks Echo endpoints
3. **Migrate all API routes to withAuth** — includes removing memoryStore and query param auth
4. **Dashboard middleware** — protects frontend
5. **Email verification (Resend)** — requires Supabase Dashboard config by user
6. **Database migration (soft delete columns)** — required before account operations
7. **Account operations API + Settings UI** — depends on migration + withAuth
8. **Mood persistence** — independent, uses existing table
9. **Timeline stats** — independent, frontend-only
10. **Connector status** — independent, frontend-only
11. **Extension manifest** — independent, trivial

Steps 8-11 are independent and can be parallelized.
