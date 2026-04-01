# Echo Dynamic First Insight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static Echo message on the Dashboard with a dynamically generated insight based on the user's real data, powered by DeepSeek.

**Architecture:** New `/api/echo/insight` endpoint receives the user's dashboard stats, assembles a system + user prompt, calls DeepSeek (non-streaming), and returns a single insight message. Dashboard page calls this after loading dashboard data and displays the result in the Echo card.

**Tech Stack:** Next.js 16 App Router, DeepSeek Chat API (same as existing `/api/echo/chat`), existing `/api/dashboard` for data

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `web/src/app/api/echo/insight/route.ts` | Create | Generate dynamic insight via DeepSeek |
| `web/src/app/dashboard/page.tsx` | Modify | Echo card fetches and displays dynamic insight |

---

### Task 1: Create Echo Insight API

**Files:**
- Create: `web/src/app/api/echo/insight/route.ts`

- [ ] **Step 1: Create the insight API route**

```ts
const DEEPSEEK_API_KEY = "sk-94d311f460e54b4cac9c216ed8d5af36";
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

const NO_DATA_MESSAGE = "连接你的手机或安装浏览器扩展，我就能开始了解你了。第一个发现可能会让你惊讶。";

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { stats, timeline_count, has_data, hour, user_name } = body;

    // No data — return static welcome
    if (!has_data) {
      return Response.json({ message: NO_DATA_MESSAGE });
    }

    // Build dynamic user prompt
    const parts: string[] = [];
    parts.push(`当前时间：${hour < 6 ? "深夜" : hour < 12 ? "上午" : hour < 14 ? "中午" : hour < 18 ? "下午" : hour < 22 ? "晚上" : "深夜"}`);
    if (user_name) parts.push(`用户名：${user_name}`);
    parts.push("");
    parts.push("今日数据：");
    if (stats.steps > 0) parts.push(`- 步数：${stats.steps.toLocaleString()}`);
    if (stats.sleep_hours > 0) parts.push(`- 睡眠：${stats.sleep_hours}小时`);
    if (stats.screen_time_minutes > 0) {
      const h = Math.floor(stats.screen_time_minutes / 60);
      const m = stats.screen_time_minutes % 60;
      parts.push(`- 屏幕时间：${h > 0 ? h + "小时" : ""}${m > 0 ? m + "分钟" : ""}`);
    }
    if (stats.mood_latest) {
      parts.push(`- 心情：${stats.mood_latest.emoji} ${stats.mood_latest.name}（${stats.mood_count}条记录）`);
    }
    if (timeline_count > 0) parts.push(`- 今日事件数：${timeline_count}个`);

    parts.push("");
    parts.push("请基于以上数据，生成一句话。");

    const userPrompt = parts.join("\n");

    const response = await fetch(DEEPSEEK_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
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
    const message = result.choices?.[0]?.message?.content?.trim() || "在这里陪着你。";

    return Response.json({ message });
  } catch {
    return Response.json({ message: "在这里陪着你。" });
  }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/looanli/Projects/ToDay/web && npx next build 2>&1 | tail -5`
Expected: `✓ Compiled successfully`

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/api/echo/insight/route.ts
git commit -m "feat: add /api/echo/insight endpoint for dynamic Echo messages"
```

---

### Task 2: Connect Dashboard Echo Card to Dynamic Insight

**Files:**
- Modify: `web/src/app/dashboard/page.tsx`

- [ ] **Step 1: Add echoMessage state and fetch logic**

In the DashboardPage component, after the existing state declarations (around line 62), add a new state:

Find:
```tsx
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
```

Replace with:
```tsx
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [echoMessage, setEchoMessage] = useState("");
  const [echoLoading, setEchoLoading] = useState(true);
```

- [ ] **Step 2: Add Echo insight fetch after dashboard data loads**

In the useEffect, after `setData(json)`, add the Echo insight call. Find the block:

```tsx
            const res = await fetch(`/api/dashboard?token=${profile.sync_token}`);
            const json = await res.json();
            setData(json);
          } catch {
            setData({ stats: { steps: 0, sleep_hours: 0, screen_time_minutes: 0, mood_latest: null, mood_count: 0 }, timeline: [], has_data: false });
          }
```

Replace with:
```tsx
            const res = await fetch(`/api/dashboard?token=${profile.sync_token}`);
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
            setData({ stats: { steps: 0, sleep_hours: 0, screen_time_minutes: 0, mood_latest: null, mood_count: 0 }, timeline: [], has_data: false });
            setEchoLoading(false);
          }
```

- [ ] **Step 3: Update the Echo card to display dynamic message**

Find the static Echo message block (around line 242-264):

```tsx
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
```

Replace with:
```tsx
            {/* Echo AI */}
            <Link href="/dashboard/echo" className="block">
              <Card className="border border-border/40 bg-card rounded-xl p-6 hover:shadow-sm transition-shadow duration-300 cursor-pointer">
                <div className="flex items-center gap-2 mb-4">
                  <EchoSymbol size={15} className="text-primary" />
                  <h2 className="font-display text-lg text-foreground">Echo</h2>
                </div>
                <div className="rounded-xl bg-background p-4 mb-3">
                  {echoLoading ? (
                    <div className="flex items-center gap-2">
                      <div className="h-2 w-2 rounded-full bg-primary/40 animate-pulse" />
                      <div className="h-2 w-2 rounded-full bg-primary/30 animate-pulse" style={{ animationDelay: "0.3s" }} />
                      <div className="h-2 w-2 rounded-full bg-primary/20 animate-pulse" style={{ animationDelay: "0.6s" }} />
                    </div>
                  ) : (
                    <>
                      <p className="text-sm text-foreground/70 leading-relaxed">
                        {echoMessage.startsWith("「") ? echoMessage : `「${echoMessage}」`}
                      </p>
                      <p className="mt-2 text-[11px] text-muted-foreground">Echo · 刚刚</p>
                    </>
                  )}
                </div>
                <p className="text-xs text-muted-foreground text-center">点击和 Echo 聊天 →</p>
              </Card>
            </Link>
```

- [ ] **Step 4: Verify build**

Run: `cd /Users/looanli/Projects/ToDay/web && npx next build 2>&1 | tail -5`
Expected: `✓ Compiled successfully`

- [ ] **Step 5: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/dashboard/page.tsx
git commit -m "feat: Echo card shows dynamic AI-generated insight based on user data"
```

---

### Task 3: Build Verify and Push

- [ ] **Step 1: Full build verify**

```bash
cd /Users/looanli/Projects/ToDay/web && npx next build 2>&1 | tail -15
```

Expected: All routes compile, `✓ Compiled successfully`

- [ ] **Step 2: Push to production**

```bash
cd /Users/looanli/Projects/ToDay && git push origin main
```

- [ ] **Step 3: Test on live site**

1. Open Dashboard as a user with browsing data
2. Echo card should show breathing dots while loading
3. After 1-2 seconds, a dynamic message appears based on real data
4. The message should NOT be a data report (no "你今天走了X步")
5. Click Echo card → navigates to `/dashboard/echo`
6. Test as a user with NO data → should show "连接你的手机或安装浏览器扩展..."
