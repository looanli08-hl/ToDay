# Echo Dynamic First Insight

## Context

The Dashboard Echo card currently shows a hardcoded static message. Echo should generate a dynamic, personalized message based on the user's real data every time they open the Dashboard. This is the core differentiator — Echo is not a health app that reports numbers, but a companion that helps users understand themselves deeper and live better.

## Goal

When a user opens the Dashboard, the Echo card shows a dynamically generated message based on their real data. The message should feel like it comes from a companion who knows your life — not a data dashboard.

## What Echo Can Do (Not Limited To)

Echo's responses should be contextual and varied:
- Affirm good habits: "你这周每天都在运动，已经坚持两周了。"
- Gentle reminders: "你最近学习时间比上周少了，期中快到了？"
- Emotional resonance: "看起来今天心情不错，是有什么好事吗？"
- Rhythm awareness: "你今天比平时早起了一个小时，精神怎么样？"
- Reflective questions: "你最近娱乐时间增加了不少，是在放松还是在逃避什么？"
- Cross-data patterns: "你运动量增加后心情也变好了，这个规律值得保持。"
- Simple companionship: "今天过得怎么样？"

What Echo should NEVER do:
- Report raw data like a dashboard ("你今天走了8000步")
- Give generic health advice ("记得多喝水")
- Sound like a robotic notification

## Architecture

```
Dashboard loads
  → Fetches /api/dashboard (already built, returns stats + timeline)
  → Passes data summary to /api/echo/insight (new endpoint)
  → DeepSeek generates contextual message
  → Echo card displays it
```

## API: POST /api/echo/insight

New endpoint that generates Echo's insight message.

**Request body:**
```json
{
  "stats": {
    "steps": 8432,
    "sleep_hours": 7.2,
    "screen_time_minutes": 185,
    "mood_latest": { "emoji": "😊", "name": "开心" },
    "mood_count": 2
  },
  "timeline_count": 8,
  "has_data": true,
  "hour": 14,
  "user_name": "Hanlin"
}
```

**Response:**
```json
{
  "message": "你这两天下午都在用效率工具，看来找到了自己的专注节奏。"
}
```

**System prompt (fixed):**
```
你是 Echo，用户的数字生活伙伴。你了解他们的生活数据，用这些来帮助他们更深地认识自己、更好地生活。

你可以：肯定好的习惯、温柔地提醒、共鸣情绪、感知节奏变化、引发自省、发现跨维度的模式、或只是简单地陪伴。

说什么取决于数据里什么最值得此刻说。像一个真正了解对方的老朋友那样说话。

规则：
- 一句话，不超过50字，中文
- 绝不复述原始数据（如"你今天走了8000步"）
- 绝不给泛泛的健康建议（如"记得多喝水"）
- 根据当前时间调整语气（早上温暖鼓励、深夜关心）
- 如果数据充足，优先做跨维度关联
- 如果数据不多，简单陪伴也可以
```

**User prompt (dynamic, assembled from request data):**
```
当前时间：下午2点
用户名：Hanlin

今日数据：
- 步数：8,432
- 睡眠：7.2小时
- 屏幕时间：3小时5分钟
- 心情：开心（2条记录）
- 时间线事件：8个

请基于以上数据，生成一句话。
```

**No data case:**
When `has_data` is false, skip DeepSeek call and return a static welcome message:
```json
{
  "message": "连接你的手机或安装浏览器扩展，我就能开始了解你了。第一个发现可能会让你惊讶。"
}
```

## Dashboard Echo Card Changes

**File:** `web/src/app/dashboard/page.tsx`

Current: Static hardcoded message "今天看起来很充实。下午记得休息一下眼睛"

New behavior:
1. After `/api/dashboard` returns, if `has_data` is true, call `/api/echo/insight` with the data
2. While loading: show a gentle breathing/pulse animation (not skeleton)
3. On success: display the generated message
4. On error/timeout (3s): show a simple fallback like "在这里陪着你。"

The Echo card should also link to the full Echo chat page when clicked.

## Non-Goals

- Echo chat page changes (separate effort)
- iOS Echo changes (separate effort)
- Historical data analysis (Part 2: heart-triggered system)
- Conversation persistence
- Multiple messages / conversation in the card

## File Changes

| File | Action |
|------|--------|
| `web/src/app/api/echo/insight/route.ts` | Create — generates dynamic insight via DeepSeek |
| `web/src/app/dashboard/page.tsx` | Modify — Echo card fetches and displays dynamic insight |
