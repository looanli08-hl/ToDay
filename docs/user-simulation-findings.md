# Attune User Simulation Findings

> 5 users simulated across a full day of usage. 2026-04-02.

## Users Simulated

| User | Profile | Core Finding |
|------|---------|-------------|
| 小张 | Chinese CS student, procrastinator, late sleeper | Echo can't answer "我今天过得怎么样" — breaks the illusion |
| Sarah | US content creator, 15K YouTube subscribers | Wants daily summary: "what did you learn about me?" |
| 阿明 | Chinese PM, office worker, privacy-conscious | Echo exposed his job search at work — social disaster |
| Tom | US senior developer, privacy-first, skeptical | Cross-source context linking is the ONE moment that converts skeptics |
| 小美 | Chinese non-tech marketing worker | Can't install — developer mode is a death trap |

---

## Critical Findings (Cross-User)

### 1. Echo Observes But Can't Remember

**Appeared in:** All 5 users

The chat API receives current page context but NOT today's browsing history, video list, or session data. When users ask "what did I do today?" or "what did you learn about me?", Echo gives a generic response indistinguishable from ChatGPT.

This is the #1 product-breaking gap. The entire value proposition is "an AI that watches alongside you." If it can't recall what it watched, the companion illusion collapses.

> 小张 at 10:30 PM: "你不是一直在看我吗，怎么什么都不知道？"

### 2. No Daily Summary

**Appeared in:** All 5 users

Every user wanted an end-of-day reflection. This is the strongest retention hook — "what did I discover about myself today?" The data exists in session storage but is never synthesized.

### 3. Proactive Triggers Are Too Mechanical

**Appeared in:** 小张, 阿明, Tom, Sarah

Count-based triggers (every 5 videos, 3+ skips) miss the most powerful moments:
- 小张 watching "How to Stay Focused" videos instead of actually working (irony detection)
- 阿明 searching job-related content (cross-platform pattern)
- Tom's Stack Overflow research connecting to a YouTube video (cross-source linking)
- Sarah's shift from strategy research to creative inspiration (mood detection)

The video titles are captured but never analyzed for semantic meaning.

### 4. Installation Is a Death Trap for Non-Tech Users

**Appeared in:** 小美 (100% failure without help), 小张 (needed friend's help)

Developer mode + load unpacked + find manifest.json folder = 95%+ drop-off for non-technical users. Chrome Web Store listing is the #1 prerequisite for reaching real users.

Sync token copy-paste is also confusing. Should be replaced by in-extension OAuth login.

### 5. Privacy Controls Are Missing

**Appeared in:** 阿明, Tom

- No domain blacklist (can't exclude work tools like Feishu, Jira)
- No data transparency dashboard (can't see what Echo collected)
- No work mode / sensitive topic detection
- 阿明's nightmare: Echo surfacing job-search content at work where coworkers can see

### 6. YouTube-Only Perception Is Too Narrow

**Appeared in:** 小张, 阿明

- Bilibili is THE primary video platform for Chinese users — Echo is blind to it
- Zhihu, Xiaohongshu, V2EX browsing generates no Echo commentary
- HN, Reddit, Stack Overflow research goes unrecognized for developers

### 7. Proactive Messages Have No Delivery Mechanism

**Appeared in:** 小张

Messages appear silently in the Side Panel. If the panel is closed or the user is looking at another tab, they miss it entirely. No notification badge, no sound, nothing.

---

## What Actually Works

| What | Why It Works |
|------|-------------|
| Echo's silence during focused work | Users appreciate not being nagged — trust is built by absence |
| First proactive message (when quality is good) | The "it actually noticed" moment hooks users |
| Welcome message tone | "你先随便逛，我在旁边看着" — not needy, not assistant-like |
| Topic shift detection | Sarah: strategy→production pivot. 小张: anxiety→curiosity shift at night |
| Visual design | Warm cream palette, serif logo, clean layout — feels premium |
| Context bar | Users liked seeing Echo knows what they're watching |

---

## Priority Action Plan

### P0 — Blocks Core Value (do these first)

| # | Action | Impact | Effort |
|---|--------|--------|--------|
| 1 | **Feed session data into chat API** — send today's browsing sessions + YouTube video history as context to Echo chat | Fixes "Echo can't remember what it observed" — the #1 illusion-breaker | Medium |
| 2 | **Daily summary** — on-demand "how was my day" synthesis, or auto-trigger at end of day | #1 retention hook, requested by all 5 users | Medium |
| 3 | **Chrome Web Store listing** — get the extension approved and published | Non-tech users literally cannot install without this | External |

### P1 — Significantly Improves Experience

| # | Action | Impact | Effort |
|---|--------|--------|--------|
| 4 | **Semantic proactive triggers** — analyze video titles for patterns, not just count | Catches irony, anxiety spirals, topic evolution — the "magic" moments | Medium |
| 5 | **In-extension OAuth** — login directly in Side Panel, no sync token | Removes the biggest onboarding friction after CWS | Medium |
| 6 | **Notification badge** — show badge on extension icon when Echo has something to say | Users miss proactive messages when Side Panel is closed | Small |
| 7 | **Domain blacklist** — let users exclude work sites from tracking | Essential for workplace users, privacy trust | Small |
| 8 | **Multiple video recommendations** — when user asks for suggestions, give 3-5 not 1 | Richer interaction, feels more like a real friend | Small (prompt change) |

### P2 — Expands Reach

| # | Action | Impact | Effort |
|---|--------|--------|--------|
| 9 | **Bilibili content script** — video detection for bilibili.com | Essential for Chinese market — more important than YouTube for many users | Medium |
| 10 | **Cross-source context linking** — connect research (SO/MDN) with videos on same topic | The killer feature for developers — Tom's "aha" moment | Large |
| 11 | **Sensitive topic detection** — suppress proactive messages about job search, health, etc. at work | Prevents 阿明's nightmare scenario | Medium |
| 12 | **End-of-day reflection trigger** — auto-message at user's typical end-of-day time | Natural retention hook without user needing to ask | Small |

---

## User Retention Predictions

| User | Would use Day 2? | Would use Day 7? | What determines retention? |
|------|-------------------|-------------------|--------------------------|
| 小张 | Yes (passively) | Maybe | Does Echo get smarter or stay the same? |
| Sarah | Yes (evaluating) | Yes if improved | Needs cross-session memory by Day 7 |
| 阿明 | At home only | Unlikely | Needs work mode + deeper insights |
| Tom | Yes (in sandbox) | Yes if cross-source works | Needs data transparency + research synthesis |
| 小美 | Couldn't install | N/A | Needs Chrome Web Store |

---

## The One Sentence Summary

> Echo's architecture captures rich browsing data but fails to feed it back into the conversation — making it an AI that watches everything but remembers nothing when asked.

Fix #1 (session data in chat context) and #2 (daily summary) and Attune goes from "interesting concept" to "I need to tell my friends about this."
