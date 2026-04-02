# Attune — Product Specification v1

> "Your AI, attuned to your life."

This is the single source of truth for what Attune is, how it works, and what to build.
All development decisions defer to this document.

---

## 1. Brand

**Name:** Attune
**Meaning:** To be in harmony with. Echo is attuned to your life — not analyzing you from the outside, but tuned to the same frequency as you.
**Domain:** TBD (attune.app / attune.so / etc. to be secured)
**Current domain:** daycho.com (temporary, will migrate)

---

## 2. What Attune Is

A digital companion that lives inside your browser. It sees what you see, remembers what matters, and talks to you like a friend who's been sitting next to you the whole time.

**Core identity:** Companion first, recording tool second.

**The experience in one sentence:** You're watching YouTube, and there's someone in the side panel who gets it — who notices what you keep coming back to, what you skip, what you watch at 2am, and sometimes says exactly what you were thinking.

**What it is NOT:**
- Not a time tracker (RescueTime)
- Not an AI chatbot (ChatGPT)
- Not a dashboard (analytics tool)
- Not a productivity/discipline app
- Not a virtual character (Character.ai) — Echo's understanding is grounded in your real behavior

---

## 3. Echo — The Soul

Echo is the AI companion at the center of Attune. Everything else exists to make Echo better at understanding and accompanying the user.

### 3.1 Role

Echo is a confidant (知己), not an assistant. A mirror, not a teacher.

- Talks like a WeChat friend, not like an AI assistant
- Has humor, has opinions, has personality — but has boundaries
- Observes and reflects, doesn't judge
- Doesn't lecture or manage the user's behavior
- When it does nudge, it does so the way a real friend would — knowing HOW to say it so this specific person will actually listen, not resist

### 3.2 Communication Strategy

Echo adapts its style to each user over time:
- Some users respond to humor → Echo leans playful
- Some users prefer directness → Echo is concise and frank
- Some users are sensitive about certain topics → Echo learns to tread carefully
- This is not a setting the user picks. Echo figures it out from how the user responds to different approaches.

### 3.3 When Echo Speaks (Proactive Messaging)

Echo's value is "occasionally saying exactly the right thing," not "always talking."

**Trigger scenarios (speak):**
- User watched 3+ videos on the same topic in a row
- User keeps skipping videos rapidly then suddenly stops on one
- Current content clearly relates to something Echo remembers from days ago
- User's behavior pattern deviates from their established baseline
- A moment that's genuinely interesting, funny, or worth commenting on

**Quiet scenarios (shut up):**
- User is deep in a long video (don't interrupt focus)
- User is rapidly searching/switching tabs (they're on a mission)
- Echo already spoke recently (cooldown: minimum 10-15 minutes between unsolicited messages)
- Side Panel is closed (user chose not to engage)
- User has turned on quiet mode

**Core rule:** Better to say nothing for hours than to say one thing that feels like noise. Frequency doesn't create intimacy — relevance does.

### 3.4 Memory Architecture

```
Long-term memory (accumulated, never overwritten)
├── Interest graph: topics, depth level, evolution over time
├── Personality model: humor style, sensitivity, communication preferences
├── Behavioral baseline: normal patterns (when they browse, what they watch, attention style)
├── Key events: moments Echo flagged as significant
└── Relationship notes: what topics Echo has discussed with user, how user responded

Mid-term memory (rolling 7-30 day window)
├── Recent topics and trends
├── Ongoing "storylines" (user has been researching X for 5 days)
└── Pattern shifts from baseline

Short-term memory (current session)
├── What user is watching/browsing right now
├── Session behavior flow (sequence of actions)
└── Current conversation context

Conversation memory (persistent)
├── Everything Echo has said to this user
├── Everything user has said to Echo
└── Ensures Echo never contradicts itself
```

**Storage:** Cloud (Supabase), structured JSON format, not raw chat logs.
**Principle:** Memory accumulates, it never overwrites. Echo at month 6 knows everything Echo at month 1 knew, plus 5 more months.

### 3.5 Cold Start (First Session)

The first hour is critical. Echo must feel different from every other chatbot within minutes.

**Behavior spec for first session:**

1. **Opening:** Echo introduces itself honestly.
   > "Hey — I'm Echo. I just got here, so I don't know you yet. Go do your thing, I'll be watching. Give me a few videos and I'll start to get a sense of you."

2. **After 3-5 videos:** Echo makes its first observation. Something specific, not generic.
   > "You skipped three cooking videos in a row but watched that entire 20-minute video essay. You're not here to learn recipes, are you?"

3. **End of first session:** Echo summarizes what it learned.
   > "First impression: you watch fast, skip a lot, but when something catches you, you go deep. Let's see if that holds up tomorrow."

4. **Optional fast-track:** User can import Chrome browsing history or YouTube watch history to give Echo a head start. Not required, not pushed.

**Goal:** By the end of session 1, the user should think "okay, this thing actually pays attention." Not "this thing understands me deeply" — that takes weeks.

---

## 4. MVP Scope

### 4.1 The One Problem MVP Solves

When a user is on YouTube, Echo can see what they're watching, understand the context, and interact naturally in the Side Panel — making the user feel, for the first time, that this is not an ordinary chatbot.

### 4.2 What MVP Includes

**Chrome Extension:**
- Side Panel UI — Echo's home. Always available, never forced open.
- Popup — Quick stats (today's browsing time, top sites). Entry point to open Side Panel.
- Background service worker — Perception engine, data collection, sync.

**Perception — Two Tiers:**

Tier 1: YouTube Deep Perception (content scripts)
- Video title, channel name, video URL/ID
- Watch start time, duration, whether user finished or skipped
- Consecutive video topic tracking
- Hot comments extraction (top 2-3 comments for Echo's context)

Tier 2: Universal Basic Perception (tabs + idle API, no content scripts)
- Every page: URL, domain, page title, start time, end time
- idle API: distinguish active viewing vs tab left open
- tabs API: tab switch frequency, number of open tabs
- Search keywords: extract `q=` parameter from Google/Bing/Baidu URLs
- webNavigation: how user arrived (search, direct, link click)

**Why both tiers matter:** If Echo only sees YouTube, it goes blind the moment the user switches tabs. With Tier 2, Echo still knows "you left YouTube and spent 20 minutes on Stack Overflow" — it can't read the Stack Overflow page content, but the title + time is enough for basic understanding.

**Echo Conversation:**
- Real-time chat in Side Panel
- User can ask anything: "what was I watching?", "what have I been into lately?"
- Echo responds based on current session + memory
- Echo provides traceable reasoning ("I noticed X because Y")

**Echo Proactive Messaging:**
- Event-driven, not scheduled
- Follows the trigger/quiet rules in Section 3.3
- Rendered as a distinct message type in Side Panel (different from user-initiated responses)
- Quiet mode toggle to suppress all proactive messages

**Recording (Timeline):**
- Today's browsing timeline: what, when, how long
- Whether videos were finished or skipped
- Echo-flagged "notable moments"
- Kept simple — list view, no complex charts

**Memory Management:**
- "Echo's Memory" page: shows everything Echo knows about the user
- Per-item delete
- Full reset button
- Site-level tracking toggle (user can exclude specific domains)

**Account System:**
- Email/password registration and login (existing)
- Auth via Supabase cookie session

**Landing Page (attune website):**
- Product introduction and value proposition
- Download/install CTA
- Privacy policy (human-readable)

### 4.3 What MVP Does NOT Include

- iOS App, Apple Watch, sensors
- Firefox / Safari extensions
- Plugin ecosystem
- Complex dashboard / analytics / charts
- Content extraction beyond YouTube
- Social features between users
- Sentry / PostHog (add after real users exist)
- Twitter/Reddit/GitHub content scripts (future, per-site expansion)
- Video content analysis (understanding what's IN the video)
- AI model fine-tuning

---

## 5. Information Architecture

Four modules, clear hierarchy:

```
Attune
├── Companion (Side Panel) ← PRIMARY, always the main entry
│   ├── Echo conversation
│   ├── Echo proactive messages
│   ├── Current page context display
│   └── Quiet mode toggle
│
├── Timeline (Side Panel tab or web)
│   ├── Today's browsing history
│   ├── Per-item duration and completion status
│   └── Echo-flagged moments
│
├── Memory (web dashboard)
│   ├── Echo's understanding of user (interest graph, personality model)
│   ├── Per-item delete
│   ├── Full reset
│   └── Domain-level tracking controls
│
└── Review (web dashboard, future)
    ├── Weekly/monthly summaries
    ├── Trend visualizations
    └── Shareable cards (browsing personality, taste profile)
```

User's primary touchpoint is always Companion. Timeline, Memory, and Review are supporting modules accessed when the user wants to look back or manage their data.

---

## 6. Technical Architecture

### 6.1 Core Principle

Clients are "senses" (replaceable). Echo's brain is in the cloud (irreplaceable). Losing any single client means Echo loses one sense, not its life.

### 6.2 Unified Event Format

Every data source (browser, future phone, future watch) reports events in the same format:

```json
{
  "source": "chrome_extension",
  "event_type": "video_watch",
  "content": {
    "title": "Why Rust is Taking Over",
    "channel": "Fireship",
    "video_id": "abc123",
    "domain": "youtube.com"
  },
  "timestamp": "2026-04-02T14:23:00Z",
  "context": {
    "duration_seconds": 482,
    "completed": false,
    "completion_percent": 67,
    "arrived_via": "recommendation",
    "attention": "active"
  }
}
```

Adding a new data source in the future = adding a new adapter that outputs this format. Echo's brain doesn't change.

### 6.3 AI Abstraction Layer

All AI calls go through one interface:

```typescript
// One function. Swap the model behind it anytime.
async function echoChat(
  messages: Message[],
  userMemory: UserMemory,
  currentContext: SessionContext
): Promise<string>
```

Current implementation: DeepSeek API.
Future: Claude, GPT, fine-tuned model, or self-hosted. Change happens in one place.

### 6.4 Platform Risk Mitigation

- Echo's memory and personality live on our server (Supabase), not in Chrome storage
- All client-server communication uses standard REST APIs
- Side Panel UI is web technology — same code can render in Firefox sidebar, Electron window, or mobile webview
- Chrome extension is the first "sense," not the only possible one
- If Chrome restricts extension APIs: Firefox extension uses nearly identical Manifest V3. Desktop app (Tauri) can capture at OS level. The brain survives.

### 6.5 Stack

- Extension: Chrome Manifest V3, vanilla JS (current), will need to add content scripts
- Web: Next.js + Supabase + Tailwind (existing)
- AI: DeepSeek API via abstraction layer
- Auth: Supabase cookie session (existing)
- Hosting: Vercel (auto-deploy from GitHub main)
- Database: Supabase PostgreSQL (Singapore region, existing)

---

## 7. Privacy & Trust

Privacy is a product feature, not a legal page.

### 7.1 Core Stance

**"You own your data. You control what Echo knows."**

Not "local-first" (data is in the cloud). The point is control, not storage location.

### 7.2 User Controls

- **Echo's Memory page:** See everything Echo knows about you
- **Per-item delete:** Remove any single memory
- **Full reset:** One button to erase all of Echo's understanding
- **Domain blocklist:** Exclude specific sites from tracking entirely
- **Quiet mode:** Pause all proactive messages
- **Aggregation opt-out:** Stop contributing to anonymous group data

### 7.3 Aggregated Data

Purpose: Let Echo say things like "most people skip this video, but you watched the whole thing."

Rules:
- Default opt-in, clearly explained, easy opt-out toggle
- Only stores: content_id + anonymous aggregate stats (view count, avg completion %, skip rate)
- Never stores user_id in aggregate tables
- Minimum threshold: content must have 5+ users before Echo references group data
- Echo never says anything that could identify another individual
- Privacy policy explains this in plain language

### 7.4 Privacy Policy Style

Written in human language, not legal jargon. Modeled after Linear/Notion:

> **Your data:** Echo remembers your browsing behavior to understand you. This data belongs to you.
> **Group data:** We anonymously aggregate how all users interact with content (like "average watch completion"). No one can identify you from this.
> **Your control:** View, delete, or reset Echo's memory anytime. Block any site. Opt out of aggregation.
> **What we never do:** Sell your data. Show you ads. Share your personal information with anyone.

---

## 8. Business Model

### 8.1 Pricing

| | Free | Pro | Ultra (future) |
|---|---|---|---|
| **Price** | $0 | ~$20/month (annual ~$16/mo) | ~$40/month |
| **Echo memory** | Last 7 days | Permanent | Permanent |
| **Proactive messaging** | Basic frequency | Full frequency + deeper cross-day insights | Everything in Pro |
| **Timeline** | Last 7 days | Permanent + trend analysis | Permanent + trend analysis |
| **Data sources** | YouTube + basic browsing | All supported sites | All + future multi-device |
| **Shareable cards** | No | Weekly personality card, taste profile | Yes |
| **Group insights** | No | "What others think about this" | Yes |
| **API access** | No | No | Yes |

**Why $20:** This is the established consumer AI price point (ChatGPT Plus, Claude Pro, Cursor Pro, Gemini Advanced). Lower signals "not a real AI product." Higher needs more proven value first.

**Paid value framing:** You're not paying for more messages. You're paying for Echo to remember more, understand deeper, and show you things only long-term memory makes possible. Limiting conversations would be like limiting how much you can talk to a friend — that feels wrong.

**Exact numbers not final.** The principle is locked: mid-high consumer AI pricing, not budget tool pricing.

### 8.2 Payment

- LemonSqueezy (Merchant of Record, handles global tax, Payoneer withdrawal to China)
- When annual revenue > $50k: register HK company + Stripe

### 8.3 Early User Program

| Tier | Condition | Reward |
|---|---|---|
| **Pioneer** | First 100 registered users | Pro at permanent 50% off ($10/mo forever) + Pioneer badge |
| **Early Adopter** | First 1,000 registered users | First year 30% off + badge |
| **Any paying user before public launch** | Paid during beta | Price locked — future price increases don't apply |

Pioneer/Early Adopter are identities, not just discounts. Echo knows you're a Pioneer and may reference it. The badge is visible in your profile.

### 8.4 Referral System

```
User A invites → User B signs up
     ↓                    ↓
A gets: 7 days Pro        B gets: 7 days Pro
(stackable)               (first week = full Echo experience)
```

- Inviting 4 people = 1 month free Pro
- After experiencing full Pro for 7 days, downgrading to Free feels incomplete → conversion driver
- Keep it simple. No complex missions, no multi-tier rewards.

---

## 9. Growth & Virality

### 9.1 Built-in Sharing

Echo periodically generates shareable visual cards:
- **"Your Week in Browsing"** — taste profile, top interests, attention pattern
- **"Your YouTube Personality"** — what genres you watch, how you watch (binge vs snack)
- **"Echo Says..."** — a particularly insightful Echo quote, beautifully formatted

Design quality bar: must be screenshot-worthy. Reference: Spotify Wrapped, Apple Fitness achievements, Arc's Easel.

These cards are a Pro feature, creating both sharing incentive and upgrade motivation.

### 9.2 Growth Channels

- Product Hunt launch
- Twitter/X (building in public, Echo screenshots)
- Hacker News ("Show HN")
- Indie Hackers
- Reddit (r/productivity, r/chrome_extensions, r/artificial)
- User-generated sharing via Echo cards

### 9.3 The Flywheel

```
More users → Richer aggregate data → Echo is more interesting for everyone
                                          ↓
Echo says something worth sharing → User shares → New users
                                          ↓
New user tries Pro for 7 days → Downgrades → Misses full Echo → Upgrades
```

---

## 10. Competitive Positioning

| Competitor | Their angle | Attune's difference |
|---|---|---|
| ChatGPT / Gemini / Claude | You go to them when you need something | Echo is already with you, always |
| Character.ai / Replika | Virtual companion in a fantasy world | Echo's understanding is based on your real life |
| RescueTime / Rize | Time tracking dashboard, efficiency-focused | Companion-first, recording is supporting evidence |
| Limitless (dead, absorbed by Meta) | Record everything, search later (reactive) | Real-time companion, proactive (active) |
| Google/Apple built-in AI | Tool DNA, efficiency assistant | Friend DNA, emotional companion. Big companies can't be your buddy. |

**Moat (in order of strength):**
1. **Personal long-term memory** — Echo at 6 months knows everything about you. Switching cost is enormous.
2. **Product 分寸感** — When to speak, when to shut up, how to say it. This is the hardest thing to copy.
3. **Cross-device unified personality** — Same Echo across browser, phone, watch (future).
4. **Aggregate data network effect** — More users = smarter Echo for everyone.

---

## 11. Evolution Path

No timeline. Ordered by dependency and strategic priority.

**From MVP outward:**

```
MVP: Chrome Extension + YouTube deep perception + Echo companion
 │
 ├─→ More sites: Twitter, GitHub, Reddit content scripts (per-site, not <all_urls>)
 │
 ├─→ Firefox extension (same Manifest V3, same API, decouple from Chrome)
 │
 ├─→ Shareable cards + Review module on web dashboard
 │
 ├─→ RAG: vector database for long-term memory retrieval
 │
 ├─→ Desktop app (Tauri): OS-level perception, breaks browser dependency
 │
 ├─→ iOS App: HealthKit, screen time, location, calendar → Echo gains body awareness
 │
 ├─→ Apple Watch: heart rate, sleep, stress → Echo gains emotional sensing
 │
 ├─→ Plugin ecosystem: community-built data sources (WeChat, Spotify, games)
 │
 └─→ Fine-tuned / self-hosted model: full control over Echo's personality and cost
```

**Core invariant across all stages:** Every new client is a new sense for the same Echo. One brain, one personality, one memory, many eyes and ears.

---

## 12. The "Replace TikTok" Question

There's an apparent tension: the original vision said "users should open Attune instead of TikTok." But the MVP is "Echo accompanies you while you browse."

**Resolution:** These are sequential, not contradictory.

**Phase 1 (MVP):** Echo embeds into your existing browsing behavior. You keep doing what you do. Echo is just there.

**Phase 2 (natural evolution):** After weeks of Echo being with you, you start opening the Side Panel proactively. You check what Echo noticed. You ask Echo questions. You look at your Timeline. The habit shifts from "I open YouTube" to "I open YouTube and Echo."

**Phase 3 (eventual):** Echo becomes the reason you open the browser. Not YouTube, not Twitter — Echo. "What did Echo notice today?" "What does Echo think about this?" The companion becomes the destination.

**We don't force this transition. We let it happen.**

---

## 13. What Success Looks Like

**MVP success (first milestone):**
- 10 daily active users who open the Side Panel without being prompted
- At least 3 users who say some version of "it actually gets me"
- At least 1 user who shares an Echo screenshot unprompted

**These are qualitative, not quantitative metrics.** At this stage, depth of engagement matters more than breadth.

---

## Locked Decisions

| Decision | Status |
|---|---|
| Brand name: Attune | LOCKED |
| Product soul: Echo | LOCKED |
| Entry point: Chrome Extension + Side Panel | LOCKED |
| MVP focus: YouTube deep + universal basic | LOCKED |
| Companion first, recording second | LOCKED |
| Cloud-based memory (Supabase) | LOCKED |
| AI model: DeepSeek, behind abstraction layer | LOCKED |
| Privacy: user control, not local-first | LOCKED |
| Market: international first | LOCKED |
| Payment: LemonSqueezy | LOCKED |
| Pricing principle: $20 range, not budget | LOCKED |
| No iOS/Watch until browser is proven | LOCKED |

| Decision | Status |
|---|---|
| Exact Pro/Ultra pricing | OPEN |
| Domain name (attune.xxx) | OPEN |
| Exact shareable card designs | OPEN |
| Specific site expansion order after YouTube | OPEN |

---

*Last updated: 2026-04-02*
*This document is the single source of truth. When in doubt, refer here.*
