# Attune MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the existing Chrome extension from a passive tracker into an AI companion (Echo) that lives in the Side Panel, perceives YouTube content in real-time, and chats like a browsing buddy.

**Architecture:** Chrome extension with three layers — perception (content scripts + tabs/idle APIs), orchestration (background service worker), and interaction (Side Panel UI). Server-side Echo brain uses DeepSeek API with Supabase-stored memory. All communication uses chrome.runtime messaging.

**Tech Stack:** Chrome Extension Manifest V3, vanilla JS (ES modules), HTML/CSS for Side Panel, Next.js API routes (existing), Supabase PostgreSQL, DeepSeek API.

**Spec reference:** `/Users/looanli/Projects/ToDay/PRODUCT_SPEC.md`

---

## File Structure Overview

**Extension (new/modified):**
```
extension/
├── manifest.json                    # MODIFY — add side_panel, content_scripts, permissions
├── src/
│   ├── background.js                # MODIFY — add message routing, perception events, proactive engine
│   ├── categories.js                # KEEP — unchanged
│   ├── popup.html                   # MODIFY — rebrand, add "Open Echo" button
│   ├── popup.js                     # MODIFY — add Side Panel open action
│   ├── sidepanel.html               # CREATE — Echo companion UI shell
│   ├── sidepanel.css                # CREATE — Attune design language
│   ├── sidepanel.js                 # CREATE — Chat controller, timeline, memory view
│   └── youtube.js                   # CREATE — YouTube content script
```

**Web API (new/modified):**
```
web/src/
├── app/api/
│   ├── echo/
│   │   ├── chat/route.ts            # MODIFY — accept context, build context-aware prompt
│   │   └── proactive/route.ts       # CREATE — generate proactive message from events
│   └── memory/route.ts              # CREATE — Echo memory CRUD
├── lib/
│   └── supabase/
│       └── migrations/
│           └── 004_echo_memory.sql  # CREATE — memory table
```

---

## Task 1: Side Panel Infrastructure

**Files:**
- Modify: `extension/manifest.json`
- Create: `extension/src/sidepanel.html`
- Create: `extension/src/sidepanel.css`
- Create: `extension/src/sidepanel.js`
- Modify: `extension/src/popup.html`
- Modify: `extension/src/popup.js`

### Side Panel setup in manifest and basic shell UI.

- [ ] **Step 1: Update manifest.json**

Add `side_panel`, `sidePanel` permission, YouTube content script, and new host permissions:

```json
{
  "manifest_version": 3,
  "name": "Attune",
  "version": "0.1.0",
  "description": "Your AI, attuned to your life.",
  "homepage_url": "https://daycho.com",
  "permissions": [
    "tabs",
    "activeTab",
    "storage",
    "alarms",
    "idle",
    "sidePanel",
    "webNavigation"
  ],
  "host_permissions": [
    "https://to-day-ten.vercel.app/*",
    "https://daycho.com/*",
    "https://api.deepseek.com/*",
    "*://*.youtube.com/*"
  ],
  "side_panel": {
    "default_path": "src/sidepanel.html"
  },
  "background": {
    "service_worker": "src/background.js",
    "type": "module"
  },
  "content_scripts": [
    {
      "matches": ["*://*.youtube.com/*"],
      "js": ["src/youtube.js"],
      "run_at": "document_idle"
    }
  ],
  "action": {
    "default_popup": "src/popup.html",
    "default_icon": {
      "16": "icons/icon16.png",
      "48": "icons/icon48.png",
      "128": "icons/icon128.png"
    }
  },
  "icons": {
    "16": "icons/icon16.png",
    "48": "icons/icon48.png",
    "128": "icons/icon128.png"
  }
}
```

- [ ] **Step 2: Create sidepanel.html**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Attune — Echo</title>
  <link rel="stylesheet" href="sidepanel.css">
</head>
<body>
  <!-- Header -->
  <header id="header">
    <div class="header-left">
      <span class="logo">Attune<span class="logo-dot">.</span></span>
    </div>
    <div class="header-right">
      <button id="quietToggle" class="icon-btn" title="Quiet mode">
        <span id="quietIcon">🔔</span>
      </button>
    </div>
  </header>

  <!-- Tab bar -->
  <nav id="tabBar">
    <button class="tab active" data-tab="companion">Echo</button>
    <button class="tab" data-tab="timeline">Timeline</button>
  </nav>

  <!-- Context bar (current page info) -->
  <div id="contextBar" class="hidden">
    <div class="context-indicator"></div>
    <span id="contextText">Watching something...</span>
  </div>

  <!-- Companion tab -->
  <div id="companionTab" class="tab-content active">
    <!-- Setup screen (shown when not connected) -->
    <div id="setupScreen" class="hidden">
      <div class="setup-content">
        <h2>Connect to Attune</h2>
        <p>Enter your sync token to get started.</p>
        <input type="text" id="tokenInput" placeholder="Paste your sync token" />
        <input type="text" id="apiBaseInput" placeholder="API URL (optional)" />
        <button id="connectBtn">Connect</button>
        <p class="setup-hint">Find your sync token at <a id="settingsLink" href="#">Settings</a></p>
      </div>
    </div>

    <!-- Chat (shown when connected) -->
    <div id="chatScreen" class="hidden">
      <div id="messages"></div>
      <div id="typingIndicator" class="hidden">
        <span class="typing-dot"></span>
        <span class="typing-dot"></span>
        <span class="typing-dot"></span>
      </div>
    </div>
  </div>

  <!-- Timeline tab -->
  <div id="timelineTab" class="tab-content">
    <div id="timelineList"></div>
  </div>

  <!-- Chat input (always visible when connected) -->
  <div id="inputBar" class="hidden">
    <textarea id="chatInput" placeholder="Ask Echo anything..." rows="1"></textarea>
    <button id="sendBtn">↑</button>
  </div>

  <script type="module" src="sidepanel.js"></script>
</body>
</html>
```

- [ ] **Step 3: Create sidepanel.css**

Design language: warm cream palette, soft typography, Apple-quality spacing.

```css
* { margin: 0; padding: 0; box-sizing: border-box; }

:root {
  --bg: #FAF8F5;
  --bg-secondary: #F0EDE8;
  --text: #2C2418;
  --text-secondary: #8A7D6B;
  --accent: #C4713E;
  --accent-light: #E8A87C;
  --border: #E6DFD3;
  --echo-bg: #F0EDE8;
  --user-bg: #C4713E;
  --user-text: #FFF;
  --radius: 16px;
  --radius-sm: 12px;
}

html, body {
  height: 100%;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  font-size: 14px;
  color: var(--text);
  background: var(--bg);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* Header */
#header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 16px;
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}
.logo {
  font-family: 'Georgia', ui-serif, serif;
  font-size: 18px;
  font-weight: 600;
  letter-spacing: -0.3px;
}
.logo-dot { color: var(--accent); }
.icon-btn {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 16px;
  padding: 4px;
  border-radius: 8px;
  transition: background 0.15s;
}
.icon-btn:hover { background: var(--bg-secondary); }

/* Tab bar */
#tabBar {
  display: flex;
  gap: 0;
  padding: 0 16px;
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}
.tab {
  flex: 1;
  padding: 10px 0;
  background: none;
  border: none;
  border-bottom: 2px solid transparent;
  font-size: 13px;
  font-weight: 500;
  color: var(--text-secondary);
  cursor: pointer;
  transition: all 0.15s;
}
.tab.active {
  color: var(--text);
  border-bottom-color: var(--accent);
}

/* Context bar */
#contextBar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  background: var(--bg-secondary);
  font-size: 12px;
  color: var(--text-secondary);
  flex-shrink: 0;
}
.context-indicator {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #10b981;
  flex-shrink: 0;
}

/* Tab content */
.tab-content { display: none; flex: 1; overflow-y: auto; }
.tab-content.active { display: flex; flex-direction: column; }

/* Setup screen */
#setupScreen {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}
.setup-content {
  text-align: center;
  max-width: 260px;
}
.setup-content h2 {
  font-size: 18px;
  margin-bottom: 8px;
}
.setup-content p {
  font-size: 13px;
  color: var(--text-secondary);
  margin-bottom: 16px;
}
.setup-content input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  font-size: 13px;
  margin-bottom: 8px;
  background: var(--bg);
  outline: none;
  transition: border-color 0.15s;
}
.setup-content input:focus { border-color: var(--accent); }
.setup-content button {
  width: 100%;
  padding: 10px;
  background: var(--accent);
  color: white;
  border: none;
  border-radius: var(--radius-sm);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  margin-top: 4px;
  transition: opacity 0.15s;
}
.setup-content button:hover { opacity: 0.9; }
.setup-hint {
  font-size: 12px;
  color: var(--text-secondary);
  margin-top: 12px;
}
.setup-hint a { color: var(--accent); }

/* Chat messages */
#chatScreen { flex: 1; overflow-y: auto; }
#messages {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 16px;
}
.message {
  max-width: 85%;
  padding: 10px 14px;
  border-radius: var(--radius);
  font-size: 13.5px;
  line-height: 1.5;
  word-wrap: break-word;
  animation: fadeIn 0.2s ease;
}
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(4px); }
  to { opacity: 1; transform: translateY(0); }
}
.message.echo {
  align-self: flex-start;
  background: var(--echo-bg);
  color: var(--text);
  border-bottom-left-radius: 4px;
}
.message.user {
  align-self: flex-end;
  background: var(--user-bg);
  color: var(--user-text);
  border-bottom-right-radius: 4px;
}
.message.proactive {
  align-self: flex-start;
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text);
  border-bottom-left-radius: 4px;
  font-style: italic;
}

/* Typing indicator */
#typingIndicator {
  display: flex;
  gap: 4px;
  padding: 8px 16px;
  align-items: center;
}
.typing-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--text-secondary);
  animation: typingBounce 1.2s infinite;
}
.typing-dot:nth-child(2) { animation-delay: 0.2s; }
.typing-dot:nth-child(3) { animation-delay: 0.4s; }
@keyframes typingBounce {
  0%, 60%, 100% { transform: translateY(0); }
  30% { transform: translateY(-4px); }
}

/* Input bar */
#inputBar {
  display: flex;
  gap: 8px;
  padding: 12px 16px;
  border-top: 1px solid var(--border);
  background: var(--bg);
  flex-shrink: 0;
  align-items: flex-end;
}
#chatInput {
  flex: 1;
  padding: 8px 12px;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  font-size: 13.5px;
  font-family: inherit;
  resize: none;
  outline: none;
  max-height: 100px;
  line-height: 1.4;
  background: var(--bg);
  transition: border-color 0.15s;
}
#chatInput:focus { border-color: var(--accent); }
#sendBtn {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: var(--accent);
  color: white;
  border: none;
  font-size: 16px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  transition: opacity 0.15s;
}
#sendBtn:hover { opacity: 0.9; }

/* Timeline */
#timelineTab { padding: 16px; }
#timelineList { display: flex; flex-direction: column; gap: 6px; }
.timeline-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  background: var(--bg-secondary);
  border-radius: var(--radius-sm);
  font-size: 13px;
}
.timeline-time {
  font-size: 12px;
  color: var(--text-secondary);
  font-variant-numeric: tabular-nums;
  flex-shrink: 0;
  min-width: 42px;
}
.timeline-title {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.timeline-duration {
  font-size: 12px;
  color: var(--text-secondary);
  flex-shrink: 0;
}
.timeline-empty {
  text-align: center;
  color: var(--text-secondary);
  padding: 40px 20px;
  font-size: 13px;
}

/* Utility */
.hidden { display: none !important; }
</css>
```

- [ ] **Step 4: Create basic sidepanel.js (shell — tabs, setup, connection)**

```javascript
// ─── Configuration ───
const DEFAULT_API_BASE = "https://daycho.com";

// ─── State ───
let state = {
  connected: false,
  syncToken: null,
  apiBaseUrl: DEFAULT_API_BASE,
  quietMode: false,
  messages: [],
  currentContext: null,
};

// ─── Init ───
async function init() {
  const stored = await chrome.storage.local.get(["syncToken", "apiBaseUrl", "quietMode", "echoMessages"]);
  state.syncToken = stored.syncToken || null;
  state.apiBaseUrl = stored.apiBaseUrl || DEFAULT_API_BASE;
  state.quietMode = stored.quietMode || false;
  state.messages = stored.echoMessages || [];
  state.connected = !!state.syncToken;

  renderAuthState();
  renderMessages();
  updateQuietIcon();
  setupListeners();
  setupMessageBus();
}

// ─── Auth State ───
function renderAuthState() {
  const setup = document.getElementById("setupScreen");
  const chat = document.getElementById("chatScreen");
  const input = document.getElementById("inputBar");

  if (state.connected) {
    setup.classList.add("hidden");
    chat.classList.remove("hidden");
    input.classList.remove("hidden");
  } else {
    setup.classList.remove("hidden");
    chat.classList.add("hidden");
    input.classList.add("hidden");
  }
}

// ─── Tabs ───
function setupListeners() {
  // Tab switching
  document.querySelectorAll(".tab").forEach(tab => {
    tab.addEventListener("click", () => {
      document.querySelectorAll(".tab").forEach(t => t.classList.remove("active"));
      document.querySelectorAll(".tab-content").forEach(c => c.classList.remove("active"));
      tab.classList.add("active");
      const target = tab.dataset.tab;
      document.getElementById(target === "companion" ? "companionTab" : "timelineTab").classList.add("active");
      if (target === "timeline") renderTimeline();
    });
  });

  // Connect button
  document.getElementById("connectBtn").addEventListener("click", async () => {
    const token = document.getElementById("tokenInput").value.trim();
    if (!token) return;
    const apiBase = document.getElementById("apiBaseInput").value.trim() || DEFAULT_API_BASE;
    state.syncToken = token;
    state.apiBaseUrl = apiBase;
    state.connected = true;
    await chrome.storage.local.set({ syncToken: token, apiBaseUrl: apiBase });
    renderAuthState();
    // Send welcome message on first connect
    if (state.messages.length === 0) {
      addEchoMessage("Hey — I'm Echo. I just got here, so I don't know you yet. Go do your thing, I'll be watching. Give me a few videos and I'll start to get a sense of you.");
    }
  });

  // Settings link
  document.getElementById("settingsLink").addEventListener("click", (e) => {
    e.preventDefault();
    chrome.tabs.create({ url: `${state.apiBaseUrl}/dashboard/settings` });
  });

  // Quiet mode toggle
  document.getElementById("quietToggle").addEventListener("click", async () => {
    state.quietMode = !state.quietMode;
    await chrome.storage.local.set({ quietMode: state.quietMode });
    updateQuietIcon();
  });

  // Send message
  document.getElementById("sendBtn").addEventListener("click", sendMessage);
  document.getElementById("chatInput").addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });

  // Auto-resize textarea
  document.getElementById("chatInput").addEventListener("input", (e) => {
    e.target.style.height = "auto";
    e.target.style.height = Math.min(e.target.scrollHeight, 100) + "px";
  });
}

// ─── Message Bus (background ↔ side panel) ───
function setupMessageBus() {
  chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    if (msg.type === "context_update") {
      state.currentContext = msg.data;
      updateContextBar();
    } else if (msg.type === "proactive_message") {
      if (!state.quietMode) {
        addProactiveMessage(msg.text);
      }
    }
    return false;
  });

  // Request initial context from background
  chrome.runtime.sendMessage({ type: "get_context" });
}

// ─── Context Bar ───
function updateContextBar() {
  const bar = document.getElementById("contextBar");
  const text = document.getElementById("contextText");
  if (state.currentContext && state.currentContext.title) {
    bar.classList.remove("hidden");
    const ctx = state.currentContext;
    if (ctx.source === "youtube") {
      text.textContent = `Watching: ${ctx.title}`;
    } else {
      text.textContent = ctx.domain || ctx.title;
    }
  } else {
    bar.classList.add("hidden");
  }
}

// ─── Chat ───
async function sendMessage() {
  const input = document.getElementById("chatInput");
  const text = input.value.trim();
  if (!text || !state.connected) return;

  input.value = "";
  input.style.height = "auto";
  addUserMessage(text);
  await streamEchoResponse(text);
}

async function streamEchoResponse(userMessage) {
  const typing = document.getElementById("typingIndicator");
  typing.classList.remove("hidden");
  scrollToBottom();

  try {
    const body = {
      messages: state.messages.slice(-20).map(m => ({
        role: m.role === "echo" || m.role === "proactive" ? "assistant" : "user",
        content: m.text,
      })),
      context: state.currentContext,
    };

    const res = await fetch(`${state.apiBaseUrl}/api/echo/chat`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${state.syncToken}`,
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) throw new Error(`API error: ${res.status}`);

    typing.classList.add("hidden");

    // Stream SSE response
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let echoText = "";
    const msgEl = createMessageElement("echo");
    document.getElementById("messages").appendChild(msgEl);

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const chunk = decoder.decode(value, { stream: true });
      const lines = chunk.split("\n");
      for (const line of lines) {
        if (!line.startsWith("data: ")) continue;
        const data = line.slice(6);
        if (data === "[DONE]") continue;
        try {
          const parsed = JSON.parse(data);
          const content = parsed.choices?.[0]?.delta?.content;
          if (content) {
            echoText += content;
            msgEl.textContent = echoText;
            scrollToBottom();
          }
        } catch {}
      }
    }

    if (echoText) {
      state.messages.push({ role: "echo", text: echoText, time: Date.now() });
      saveMessages();
    }
  } catch (err) {
    typing.classList.add("hidden");
    addEchoMessage("Sorry, I couldn't connect right now. Try again in a moment.");
    console.error("[Echo] Stream error:", err);
  }
}

// ─── Message Rendering ───
function addUserMessage(text) {
  state.messages.push({ role: "user", text, time: Date.now() });
  const el = createMessageElement("user");
  el.textContent = text;
  document.getElementById("messages").appendChild(el);
  saveMessages();
  scrollToBottom();
}

function addEchoMessage(text) {
  state.messages.push({ role: "echo", text, time: Date.now() });
  const el = createMessageElement("echo");
  el.textContent = text;
  document.getElementById("messages").appendChild(el);
  saveMessages();
  scrollToBottom();
}

function addProactiveMessage(text) {
  state.messages.push({ role: "proactive", text, time: Date.now() });
  const el = createMessageElement("proactive");
  el.textContent = text;
  document.getElementById("messages").appendChild(el);
  saveMessages();
  scrollToBottom();
}

function createMessageElement(type) {
  const el = document.createElement("div");
  el.className = `message ${type}`;
  return el;
}

function renderMessages() {
  const container = document.getElementById("messages");
  container.innerHTML = "";
  for (const msg of state.messages) {
    const el = createMessageElement(msg.role);
    el.textContent = msg.text;
    container.appendChild(el);
  }
  scrollToBottom();
}

function scrollToBottom() {
  const chat = document.getElementById("chatScreen");
  requestAnimationFrame(() => { chat.scrollTop = chat.scrollHeight; });
}

async function saveMessages() {
  // Keep last 100 messages in local storage
  const toSave = state.messages.slice(-100);
  await chrome.storage.local.set({ echoMessages: toSave });
}

// ─── Quiet Mode ───
function updateQuietIcon() {
  document.getElementById("quietIcon").textContent = state.quietMode ? "🔕" : "🔔";
}

// ─── Timeline ───
async function renderTimeline() {
  const list = document.getElementById("timelineList");
  const todayKey = new Date().toISOString().split("T")[0];
  const result = await chrome.storage.local.get(["sessions", "currentSession"]);
  const sessions = result.sessions?.[todayKey] || [];

  // Include current session
  const all = [...sessions];
  if (result.currentSession) {
    const dur = Math.round((Date.now() - result.currentSession.startTime) / 1000);
    if (dur >= 5) {
      all.push({ ...result.currentSession, endTime: Date.now(), duration: dur });
    }
  }
  all.sort((a, b) => b.startTime - a.startTime);

  if (all.length === 0) {
    list.innerHTML = '<div class="timeline-empty">Start browsing — your timeline will appear here.</div>';
    return;
  }

  list.innerHTML = all.map(s => {
    const time = new Date(s.startTime).toLocaleTimeString("en", { hour: "2-digit", minute: "2-digit", hour12: false });
    const dur = s.duration < 60 ? `${s.duration}s` : s.duration < 3600 ? `${Math.floor(s.duration / 60)}m` : `${Math.floor(s.duration / 3600)}h ${Math.floor((s.duration % 3600) / 60)}m`;
    return `<div class="timeline-item">
      <span class="timeline-time">${time}</span>
      <span class="timeline-title">${s.title || s.label || s.domain}</span>
      <span class="timeline-duration">${dur}</span>
    </div>`;
  }).join("");
}

// ─── Start ───
init();
```

- [ ] **Step 5: Update popup.html — rebrand + add Open Echo button**

Replace the logo text "ToDay." with "Attune." and add an "Open Echo" button above the settings section. In the footer, replace "ToDay Browser Extension" with "Attune". Add this button element after the divider and before the sites list title:

In popup.html, change:
- `<span class="logo-text">ToDay</span>` → `<span class="logo-text">Attune</span>`
- Footer text: `"ToDay Browser Extension"` → `"Attune"`
- Add a button: `<button id="openEchoBtn" style="width:100%;padding:10px;background:#C4713E;color:white;border:none;border-radius:12px;font-size:14px;font-weight:500;cursor:pointer;margin-bottom:12px;">Open Echo ↗</button>` right after the summary section.

- [ ] **Step 6: Update popup.js — open Side Panel on button click**

Add after the dashboard link event listener:

```javascript
document.getElementById("openEchoBtn").addEventListener("click", () => {
  chrome.sidePanel.open({ windowId: undefined });
  window.close();
});
```

- [ ] **Step 7: Update background.js — add Side Panel open behavior**

Add at the top of background.js, after the imports:

```javascript
// Open Side Panel when extension icon is clicked (action click)
chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: false });
```

And add a message listener for `get_context`:

```javascript
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === "get_context") {
    getState().then(state => {
      const context = state.currentSession ? {
        source: "browser",
        domain: state.currentSession.domain,
        title: state.currentSession.title,
        category: state.currentSession.category,
        startTime: state.currentSession.startTime,
      } : null;
      // Send to all extension pages (side panel)
      chrome.runtime.sendMessage({ type: "context_update", data: context }).catch(() => {});
    });
  }
  return false;
});
```

- [ ] **Step 8: Verify — load extension and test Side Panel**

1. Go to `chrome://extensions/`, enable Developer mode
2. Click "Load unpacked", select `extension/` folder
3. Click the Attune extension icon → popup should show with "Attune." branding and "Open Echo" button
4. Click "Open Echo" → Side Panel should open
5. Side Panel should show setup screen with token input
6. Enter a sync token → chat screen should appear with Echo's welcome message

- [ ] **Step 9: Commit**

```bash
git add extension/manifest.json extension/src/sidepanel.html extension/src/sidepanel.css extension/src/sidepanel.js extension/src/popup.html extension/src/popup.js
git commit -m "feat: add Side Panel infrastructure with Echo chat shell and Attune branding"
```

---

## Task 2: YouTube Content Script

**Files:**
- Create: `extension/src/youtube.js`
- Modify: `extension/src/background.js`

### Content script that detects YouTube video info and watch behavior.

- [ ] **Step 1: Create youtube.js content script**

```javascript
// Attune — YouTube Content Script
// Injected into youtube.com pages. Detects current video and reports to background.

(() => {
  // ─── State ───
  let currentVideoId = null;
  let watchStartTime = null;
  let lastReportTime = 0;
  const REPORT_INTERVAL = 5000; // Report progress every 5s

  // ─── Video Detection ───
  function getVideoId() {
    const params = new URLSearchParams(window.location.search);
    return params.get("v");
  }

  function getVideoInfo() {
    const videoEl = document.querySelector("video");
    const titleEl = document.querySelector("h1.ytd-watch-metadata yt-formatted-string") ||
                    document.querySelector("h1.ytd-video-primary-info-renderer");
    const channelEl = document.querySelector("ytd-channel-name yt-formatted-string a") ||
                      document.querySelector("#channel-name a");

    return {
      videoId: getVideoId(),
      title: titleEl?.textContent?.trim() || document.title.replace(" - YouTube", "").trim(),
      channel: channelEl?.textContent?.trim() || "",
      duration: videoEl?.duration || 0,
      currentTime: videoEl?.currentTime || 0,
      paused: videoEl?.paused ?? true,
    };
  }

  // ─── Report to Background ───
  function reportVideoState(eventType) {
    const info = getVideoInfo();
    if (!info.videoId) return;

    chrome.runtime.sendMessage({
      type: "youtube_event",
      event: eventType,
      data: {
        videoId: info.videoId,
        title: info.title,
        channel: info.channel,
        duration: Math.round(info.duration),
        currentTime: Math.round(info.currentTime),
        completionPercent: info.duration > 0 ? Math.round((info.currentTime / info.duration) * 100) : 0,
        paused: info.paused,
        url: window.location.href,
        timestamp: Date.now(),
      },
    }).catch(() => {}); // Side panel may not be open
  }

  // ─── Video Change Detection ───
  function checkForVideoChange() {
    const newVideoId = getVideoId();
    if (!newVideoId) return;

    if (newVideoId !== currentVideoId) {
      // Report previous video as ended (if any)
      if (currentVideoId) {
        reportVideoState("video_leave");
      }
      // Start tracking new video
      currentVideoId = newVideoId;
      watchStartTime = Date.now();
      // Wait a moment for DOM to update with new video info
      setTimeout(() => reportVideoState("video_start"), 1500);
    }
  }

  // ─── Progress Tracking ───
  function trackProgress() {
    if (!currentVideoId) return;
    const now = Date.now();
    if (now - lastReportTime < REPORT_INTERVAL) return;
    lastReportTime = now;
    reportVideoState("video_progress");
  }

  // ─── Event Listeners ───

  // YouTube SPA navigation (custom event fired by YouTube)
  window.addEventListener("yt-navigate-finish", () => {
    setTimeout(checkForVideoChange, 500);
  });

  // Fallback: URL change detection via popstate
  window.addEventListener("popstate", () => {
    setTimeout(checkForVideoChange, 500);
  });

  // Video element events
  function attachVideoListeners() {
    const video = document.querySelector("video");
    if (!video) return;

    video.addEventListener("play", () => reportVideoState("video_play"));
    video.addEventListener("pause", () => reportVideoState("video_pause"));
    video.addEventListener("ended", () => reportVideoState("video_ended"));
    video.addEventListener("timeupdate", trackProgress);
  }

  // Wait for video element to appear
  const observer = new MutationObserver(() => {
    if (document.querySelector("video")) {
      attachVideoListeners();
      observer.disconnect();
    }
  });
  observer.observe(document.body, { childList: true, subtree: true });

  // If video already exists
  if (document.querySelector("video")) {
    attachVideoListeners();
  }

  // Initial check
  checkForVideoChange();

  console.log("[Attune] YouTube perception active");
})();
```

- [ ] **Step 2: Add YouTube event handler to background.js**

Add a new state variable and handler in background.js. Add after the existing state management section:

```javascript
// ─── YouTube Perception State ───
let youtubeState = {
  currentVideo: null,
  videosThisSession: [],
  lastProactiveTime: 0,
};

// Handle YouTube content script messages
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === "youtube_event") {
    handleYouTubeEvent(msg.event, msg.data);
  }
  if (msg.type === "get_context") {
    respondWithContext();
  }
  return false;
});

function handleYouTubeEvent(eventType, data) {
  if (eventType === "video_start") {
    youtubeState.currentVideo = {
      ...data,
      watchStartTime: Date.now(),
    };
    youtubeState.videosThisSession.push(data);
    broadcastContext();
  } else if (eventType === "video_progress") {
    if (youtubeState.currentVideo) {
      youtubeState.currentVideo.currentTime = data.currentTime;
      youtubeState.currentVideo.completionPercent = data.completionPercent;
      youtubeState.currentVideo.paused = data.paused;
    }
  } else if (eventType === "video_leave" || eventType === "video_ended") {
    if (youtubeState.currentVideo) {
      youtubeState.currentVideo.completionPercent = data.completionPercent;
      youtubeState.currentVideo.endedAt = Date.now();
      youtubeState.currentVideo.completed = data.completionPercent >= 85;
      youtubeState.currentVideo.skipped = data.completionPercent < 20;
    }
    broadcastContext();
    evaluateProactiveTrigger();
  } else if (eventType === "video_pause" || eventType === "video_play") {
    if (youtubeState.currentVideo) {
      youtubeState.currentVideo.paused = data.paused;
    }
  }
}

function respondWithContext() {
  const context = youtubeState.currentVideo ? {
    source: "youtube",
    ...youtubeState.currentVideo,
    recentVideos: youtubeState.videosThisSession.slice(-10),
  } : null;
  chrome.runtime.sendMessage({ type: "context_update", data: context }).catch(() => {});
}

function broadcastContext() {
  respondWithContext();
}
```

- [ ] **Step 3: Add proactive trigger evaluation stub**

Add to background.js after the YouTube handler:

```javascript
// ─── Proactive Messaging (basic) ───
const PROACTIVE_COOLDOWN = 10 * 60 * 1000; // 10 minutes

async function evaluateProactiveTrigger() {
  const now = Date.now();
  if (now - youtubeState.lastProactiveTime < PROACTIVE_COOLDOWN) return;

  const stored = await chrome.storage.local.get(["quietMode", "syncToken", "apiBaseUrl"]);
  if (stored.quietMode || !stored.syncToken) return;

  const videos = youtubeState.videosThisSession;
  if (videos.length < 3) return; // Need at least 3 videos before speaking

  // Check trigger: consecutive same-topic videos or rapid skipping
  const recent = videos.slice(-5);
  const skippedCount = recent.filter(v => (v.completionPercent || 0) < 20).length;
  const allTitles = recent.map(v => v.title).join(" | ");

  // Only trigger if there's something interesting to say
  const shouldTrigger = skippedCount >= 3 || videos.length % 5 === 0;
  if (!shouldTrigger) return;

  try {
    const apiBase = stored.apiBaseUrl || DEFAULT_API_BASE;
    const res = await fetch(`${apiBase}/api/echo/proactive`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${stored.syncToken}`,
      },
      body: JSON.stringify({
        recentVideos: recent.map(v => ({
          title: v.title,
          channel: v.channel,
          completionPercent: v.completionPercent,
          skipped: (v.completionPercent || 0) < 20,
        })),
        totalVideosToday: videos.length,
        skippedCount,
      }),
    });

    if (res.ok) {
      const data = await res.json();
      if (data.message) {
        chrome.runtime.sendMessage({ type: "proactive_message", text: data.message }).catch(() => {});
        youtubeState.lastProactiveTime = now;
      }
    }
  } catch (err) {
    console.error("[Attune] Proactive message error:", err);
  }
}
```

- [ ] **Step 4: Verify — test YouTube content script**

1. Reload extension in `chrome://extensions/`
2. Open YouTube and play any video
3. Open Side Panel → context bar should show "Watching: [video title]"
4. Switch videos → context bar should update
5. Open DevTools on YouTube tab → console should show "[Attune] YouTube perception active"
6. Open background service worker DevTools → should see YouTube event handling

- [ ] **Step 5: Commit**

```bash
git add extension/src/youtube.js extension/src/background.js
git commit -m "feat: add YouTube content script with video detection and progress tracking"
```

---

## Task 3: Context-Aware Echo Chat API

**Files:**
- Modify: `web/src/app/api/echo/chat/route.ts`
- Create: `web/src/app/api/echo/proactive/route.ts`

### Update the Echo chat API to accept browsing context and build context-aware prompts. Add proactive message endpoint.

- [ ] **Step 1: Read the current chat route**

Read: `web/src/app/api/echo/chat/route.ts`
Understand the current DeepSeek integration, streaming setup, and system prompt.

- [ ] **Step 2: Refactor chat route to accept context**

Replace the entire `web/src/app/api/echo/chat/route.ts` with a context-aware version:

```typescript
import { withAuth } from "@/lib/api/auth";
import { NextRequest } from "next/server";

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

// ─── AI Abstraction Layer ───
async function callLLM(messages: Array<{ role: string; content: string }>, stream = true) {
  const res = await fetch("https://api.deepseek.com/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages,
      temperature: 0.75,
      max_tokens: 1024,
      stream,
    }),
  });
  return res;
}

// ─── System Prompt Builder ───
function buildSystemPrompt(context: any) {
  const now = new Date();
  const hour = now.getHours();
  const timeOfDay = hour < 6 ? "deep night" : hour < 12 ? "morning" : hour < 18 ? "afternoon" : hour < 22 ? "evening" : "late night";

  let prompt = `You are Echo, the AI companion inside Attune. You are NOT an assistant. You are a close friend who happens to be watching the user browse the internet alongside them.

PERSONALITY:
- Talk like a WeChat friend, not an AI assistant
- Be warm, casual, occasionally witty
- Have opinions but don't lecture
- Observe and reflect, don't judge
- When you notice something, say it naturally like a friend sitting next to them would
- Keep responses short and conversational (1-3 sentences usually)
- Use a mix of English and can sprinkle in Chinese naturally if the user does

RULES:
- Never say "as an AI" or "I'm an AI language model"
- Never give unsolicited productivity advice
- If you reference data, say it naturally ("I noticed you..." not "Based on my analysis...")
- You can have personality: tease gently, express genuine curiosity, share reactions
- When the user asks about their habits/patterns, be honest but kind

CURRENT TIME: ${now.toLocaleString("en-US", { timeZone: "Asia/Shanghai" })} (${timeOfDay})`;

  // Add browsing context
  if (context) {
    if (context.source === "youtube" && context.title) {
      prompt += `\n\nRIGHT NOW: The user is watching "${context.title}" by ${context.channel || "unknown channel"} on YouTube.`;
      if (context.completionPercent !== undefined) {
        prompt += ` They've watched ${context.completionPercent}% of it.`;
      }
      if (context.recentVideos && context.recentVideos.length > 1) {
        const recent = context.recentVideos.slice(-5);
        prompt += `\n\nRECENT VIDEOS (last ${recent.length}):`;
        for (const v of recent) {
          const status = v.completionPercent >= 85 ? "watched" : v.completionPercent < 20 ? "skipped" : `${v.completionPercent}%`;
          prompt += `\n- "${v.title}" (${v.channel || "?"}) — ${status}`;
        }
      }
    } else if (context.domain) {
      prompt += `\n\nRIGHT NOW: The user is on ${context.domain} (${context.title || "no title"}).`;
    }
  }

  return prompt;
}

// ─── Route Handler ───
async function handler(req: NextRequest, { userId }: { userId: string }) {
  const { messages, context } = await req.json();

  if (!messages || !Array.isArray(messages)) {
    return new Response(JSON.stringify({ error: "messages required" }), { status: 400 });
  }

  if (!DEEPSEEK_API_KEY) {
    return new Response(JSON.stringify({ error: "AI not configured" }), { status: 500 });
  }

  const systemPrompt = buildSystemPrompt(context);

  const llmMessages = [
    { role: "system", content: systemPrompt },
    ...messages.slice(-20),
  ];

  const llmRes = await callLLM(llmMessages, true);

  if (!llmRes.ok) {
    return new Response(JSON.stringify({ error: "AI service error" }), { status: 502 });
  }

  // Pass through the SSE stream
  return new Response(llmRes.body, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
}

export const POST = withAuth(handler);
```

- [ ] **Step 3: Create proactive message endpoint**

Create `web/src/app/api/echo/proactive/route.ts`:

```typescript
import { withAuth } from "@/lib/api/auth";
import { NextRequest } from "next/server";

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY;

async function handler(req: NextRequest, { userId }: { userId: string }) {
  const { recentVideos, totalVideosToday, skippedCount } = await req.json();

  if (!DEEPSEEK_API_KEY || !recentVideos || recentVideos.length === 0) {
    return Response.json({ message: null });
  }

  const videoList = recentVideos
    .map((v: any) => `- "${v.title}" (${v.channel || "?"}) — ${v.skipped ? "skipped" : `watched ${v.completionPercent}%`}`)
    .join("\n");

  const prompt = `You are Echo, a casual companion watching YouTube alongside the user. They've watched ${totalVideosToday} videos today. Here are the most recent ones:

${videoList}

${skippedCount >= 3 ? `They skipped ${skippedCount} of the last ${recentVideos.length} videos rapidly.` : ""}

Generate ONE short, natural comment (1 sentence, max 100 chars) that a friend sitting next to them would say. Be specific about the content, not generic. Don't give advice. Don't ask questions. Just react naturally.

Examples of good responses:
- "You really can't resist Fireship videos, can you"
- "Three cooking videos and you skipped them all. Not in the mood today huh"
- "You watched that whole 40-minute video essay, respect"

Examples of BAD responses (never say these):
- "It looks like you've been watching a lot of videos!"
- "Have you considered taking a break?"
- "I notice you seem interested in technology."

Respond with ONLY the comment, nothing else.`;

  try {
    const res = await fetch("https://api.deepseek.com/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.85,
        max_tokens: 100,
        stream: false,
      }),
    });

    if (!res.ok) return Response.json({ message: null });

    const data = await res.json();
    const message = data.choices?.[0]?.message?.content?.trim();
    return Response.json({ message: message || null });
  } catch {
    return Response.json({ message: null });
  }
}

export const POST = withAuth(handler);
```

- [ ] **Step 4: Verify the API endpoints**

Test the chat endpoint manually:
```bash
curl -X POST https://daycho.com/api/echo/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SYNC_TOKEN" \
  -d '{"messages":[{"role":"user","content":"hey what am I watching?"}],"context":{"source":"youtube","title":"Why Rust is Taking Over","channel":"Fireship","completionPercent":45}}'
```

Test the proactive endpoint:
```bash
curl -X POST https://daycho.com/api/echo/proactive \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SYNC_TOKEN" \
  -d '{"recentVideos":[{"title":"Rust Tutorial","channel":"Fireship","completionPercent":90,"skipped":false},{"title":"Go vs Rust","channel":"TechLead","completionPercent":15,"skipped":true}],"totalVideosToday":5,"skippedCount":1}'
```

- [ ] **Step 5: Commit**

```bash
git add web/src/app/api/echo/chat/route.ts web/src/app/api/echo/proactive/route.ts
git commit -m "feat: context-aware Echo chat API and proactive message endpoint"
```

---

## Task 4: Enhanced Universal Perception

**Files:**
- Modify: `extension/src/background.js`

### Add search keyword extraction, tab behavior tracking, and improved context broadcasting.

- [ ] **Step 1: Add search keyword extraction**

Add this function to background.js:

```javascript
// ─── Search Keyword Extraction ───
function extractSearchQuery(url) {
  try {
    const u = new URL(url);
    // Google, Bing, Baidu, DuckDuckGo
    const searchParams = ["q", "query", "wd", "keyword"];
    for (const param of searchParams) {
      const val = u.searchParams.get(param);
      if (val) return { engine: u.hostname, query: val };
    }
  } catch {}
  return null;
}
```

- [ ] **Step 2: Add tab behavior tracking**

Add tab tracking state and listeners:

```javascript
// ─── Tab Behavior Tracking ───
let tabBehavior = {
  switchCount: 0,
  lastSwitchTime: 0,
  openTabCount: 0,
  searches: [],
};

// Reset daily
chrome.alarms.create("resetTabBehavior", { periodInMinutes: 60 });

// Track tab switches
chrome.tabs.onActivated.addListener(async () => {
  tabBehavior.switchCount++;
  tabBehavior.lastSwitchTime = Date.now();
  const tabs = await chrome.tabs.query({ currentWindow: true });
  tabBehavior.openTabCount = tabs.length;
  heartbeat();
});
```

- [ ] **Step 3: Integrate search tracking into heartbeat**

In the existing `heartbeat()` function, after extracting the URL and domain, add:

```javascript
    // Track search queries
    const search = extractSearchQuery(url);
    if (search) {
      tabBehavior.searches.push({ ...search, time: now });
      // Keep last 50 searches
      if (tabBehavior.searches.length > 50) tabBehavior.searches = tabBehavior.searches.slice(-50);
    }
```

- [ ] **Step 4: Enhance context broadcasting with tab behavior and search data**

Update the `respondWithContext()` function to include richer context:

```javascript
function respondWithContext() {
  const context = youtubeState.currentVideo ? {
    source: "youtube",
    ...youtubeState.currentVideo,
    recentVideos: youtubeState.videosThisSession.slice(-10),
  } : null;

  // Enrich with tab behavior
  const enrichedContext = context ? {
    ...context,
    tabSwitchCount: tabBehavior.switchCount,
    openTabs: tabBehavior.openTabCount,
    recentSearches: tabBehavior.searches.slice(-5).map(s => s.query),
  } : null;

  chrome.runtime.sendMessage({ type: "context_update", data: enrichedContext }).catch(() => {});
}
```

- [ ] **Step 5: Broadcast context on every heartbeat**

At the end of the `heartbeat()` function, add:

```javascript
    // Broadcast context update to side panel
    broadcastContext();
```

- [ ] **Step 6: Verify — test enhanced perception**

1. Reload extension
2. Open Side Panel
3. Browse several sites including Google search
4. Open YouTube → context should show "Watching: ..."
5. Switch tabs rapidly → context should update
6. Search something on Google → search should be captured
7. Check background console for activity logs

- [ ] **Step 7: Commit**

```bash
git add extension/src/background.js
git commit -m "feat: enhanced perception — search keywords, tab behavior, rich context"
```

---

## Task 5: Memory System

**Files:**
- Create: `web/src/lib/supabase/migrations/004_echo_memory.sql`
- Create: `web/src/app/api/memory/route.ts`
- Modify: `web/src/app/api/echo/chat/route.ts`

### Supabase table for structured Echo memory + API + integration into chat context.

- [ ] **Step 1: Create memory migration SQL**

Create `web/src/lib/supabase/migrations/004_echo_memory.sql`:

```sql
-- Echo Memory: Structured understanding of each user
CREATE TABLE IF NOT EXISTS echo_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  memory_type TEXT NOT NULL CHECK (memory_type IN ('interest', 'personality', 'pattern', 'event', 'note')),
  content JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for efficient retrieval
CREATE INDEX IF NOT EXISTS idx_echo_memory_user ON echo_memory(user_id, memory_type);
CREATE INDEX IF NOT EXISTS idx_echo_memory_updated ON echo_memory(user_id, updated_at DESC);

-- RLS
ALTER TABLE echo_memory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own memory" ON echo_memory FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own memory" ON echo_memory FOR DELETE USING (auth.uid() = user_id);

-- Server-side insert (via service role or RPC)
CREATE OR REPLACE FUNCTION insert_echo_memory(
  p_user_id UUID,
  p_memory_type TEXT,
  p_content JSONB
) RETURNS UUID AS $$
DECLARE
  new_id UUID;
BEGIN
  INSERT INTO echo_memory (user_id, memory_type, content)
  VALUES (p_user_id, p_memory_type, p_content)
  RETURNING id INTO new_id;
  RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Run migration on Supabase**

Execute the SQL in the Supabase SQL editor (Dashboard → SQL Editor → paste and run).

- [ ] **Step 3: Create memory API route**

Create `web/src/app/api/memory/route.ts`:

```typescript
import { withAuth } from "@/lib/api/auth";
import { createClient } from "@/lib/supabase/server";
import { NextRequest } from "next/server";

// GET — Retrieve user's Echo memories
async function handleGet(req: NextRequest, { userId }: { userId: string }) {
  const supabase = await createClient();
  const url = new URL(req.url);
  const type = url.searchParams.get("type");

  let query = supabase
    .from("echo_memory")
    .select("*")
    .eq("user_id", userId)
    .order("updated_at", { ascending: false })
    .limit(100);

  if (type) query = query.eq("memory_type", type);

  const { data, error } = await query;
  if (error) return Response.json({ error: error.message }, { status: 500 });
  return Response.json({ memories: data });
}

// POST — Add a new memory
async function handlePost(req: NextRequest, { userId }: { userId: string }) {
  const { memory_type, content } = await req.json();
  if (!memory_type || !content) {
    return Response.json({ error: "memory_type and content required" }, { status: 400 });
  }

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("insert_echo_memory", {
    p_user_id: userId,
    p_memory_type: memory_type,
    p_content: content,
  });

  if (error) return Response.json({ error: error.message }, { status: 500 });
  return Response.json({ id: data });
}

// DELETE — Remove a specific memory or all
async function handleDelete(req: NextRequest, { userId }: { userId: string }) {
  const url = new URL(req.url);
  const id = url.searchParams.get("id");
  const supabase = await createClient();

  if (id) {
    const { error } = await supabase
      .from("echo_memory")
      .delete()
      .eq("id", id)
      .eq("user_id", userId);
    if (error) return Response.json({ error: error.message }, { status: 500 });
  } else {
    // Delete all (full reset)
    const { error } = await supabase
      .from("echo_memory")
      .delete()
      .eq("user_id", userId);
    if (error) return Response.json({ error: error.message }, { status: 500 });
  }

  return Response.json({ success: true });
}

export const GET = withAuth(handleGet);
export const POST = withAuth(handlePost);
export const DELETE = withAuth(handleDelete);
```

- [ ] **Step 4: Integrate memory into Echo chat prompt**

In `web/src/app/api/echo/chat/route.ts`, update the handler to fetch and include memories:

Add before `const systemPrompt = buildSystemPrompt(context);`:

```typescript
  // Fetch user memory for context
  const supabase = await createClient();
  const { data: memories } = await supabase
    .from("echo_memory")
    .select("memory_type, content, updated_at")
    .eq("user_id", userId)
    .order("updated_at", { ascending: false })
    .limit(20);

  const systemPrompt = buildSystemPrompt(context, memories);
```

Update `buildSystemPrompt` to accept and use memories:

```typescript
function buildSystemPrompt(context: any, memories?: any[]) {
  // ... existing prompt code ...

  // Add memory context
  if (memories && memories.length > 0) {
    prompt += "\n\nWHAT YOU KNOW ABOUT THIS USER:";
    for (const m of memories) {
      const c = m.content;
      if (m.memory_type === "interest") {
        prompt += `\n- Interested in: ${c.topic} (level: ${c.depth || "curious"})`;
      } else if (m.memory_type === "personality") {
        prompt += `\n- Personality: ${c.trait}`;
      } else if (m.memory_type === "pattern") {
        prompt += `\n- Pattern: ${c.description}`;
      } else if (m.memory_type === "event") {
        prompt += `\n- Notable: ${c.description}`;
      } else if (m.memory_type === "note") {
        prompt += `\n- Note: ${c.text}`;
      }
    }
    prompt += "\n\nUse this knowledge naturally. Don't list facts. Weave them into conversation like a friend who just knows these things about them.";
  }

  return prompt;
}
```

Add the import at the top of the file:

```typescript
import { createClient } from "@/lib/supabase/server";
```

- [ ] **Step 5: Verify — test memory API**

```bash
# Add a memory
curl -X POST https://daycho.com/api/memory \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"memory_type":"interest","content":{"topic":"Rust programming","depth":"learning"}}'

# Get memories
curl -H "Authorization: Bearer YOUR_TOKEN" https://daycho.com/api/memory

# Delete all
curl -X DELETE -H "Authorization: Bearer YOUR_TOKEN" "https://daycho.com/api/memory"
```

- [ ] **Step 6: Commit**

```bash
git add web/src/lib/supabase/migrations/004_echo_memory.sql web/src/app/api/memory/route.ts web/src/app/api/echo/chat/route.ts
git commit -m "feat: Echo memory system — Supabase storage, CRUD API, context injection"
```

---

## Task 6: Cold Start Experience

**Files:**
- Modify: `extension/src/sidepanel.js`
- Modify: `extension/src/background.js`

### First-session detection and Echo's introduction behavior.

- [ ] **Step 1: Track first-session state**

In `sidepanel.js`, update the init function to detect first session:

```javascript
async function init() {
  const stored = await chrome.storage.local.get(["syncToken", "apiBaseUrl", "quietMode", "echoMessages", "isFirstSession", "sessionCount"]);
  state.syncToken = stored.syncToken || null;
  state.apiBaseUrl = stored.apiBaseUrl || DEFAULT_API_BASE;
  state.quietMode = stored.quietMode || false;
  state.messages = stored.echoMessages || [];
  state.connected = !!state.syncToken;
  state.isFirstSession = stored.isFirstSession !== false; // default true
  state.sessionCount = stored.sessionCount || 0;

  renderAuthState();
  renderMessages();
  updateQuietIcon();
  setupListeners();
  setupMessageBus();
}
```

- [ ] **Step 2: Add first-session welcome in connect flow**

Update the connect button handler in `sidepanel.js`:

```javascript
  document.getElementById("connectBtn").addEventListener("click", async () => {
    const token = document.getElementById("tokenInput").value.trim();
    if (!token) return;
    const apiBase = document.getElementById("apiBaseInput").value.trim() || DEFAULT_API_BASE;
    state.syncToken = token;
    state.apiBaseUrl = apiBase;
    state.connected = true;
    await chrome.storage.local.set({
      syncToken: token,
      apiBaseUrl: apiBase,
      isFirstSession: true,
      sessionCount: 0,
    });
    renderAuthState();

    // First-time welcome
    addEchoMessage("Hey — I'm Echo. I just got here, so I don't know you yet. Go do your thing, I'll be watching. Give me a few videos and I'll start to get a sense of you.");
  });
```

- [ ] **Step 3: Trigger first observation after 3-5 YouTube videos**

In `background.js`, update `evaluateProactiveTrigger()` to handle first-session special case:

```javascript
async function evaluateProactiveTrigger() {
  const now = Date.now();
  if (now - youtubeState.lastProactiveTime < PROACTIVE_COOLDOWN) return;

  const stored = await chrome.storage.local.get(["quietMode", "syncToken", "apiBaseUrl", "isFirstSession", "sessionCount"]);
  if (stored.quietMode || !stored.syncToken) return;

  const videos = youtubeState.videosThisSession;
  const apiBase = stored.apiBaseUrl || DEFAULT_API_BASE;

  // ─── First session special trigger ───
  if (stored.isFirstSession && videos.length >= 3 && stored.sessionCount === 0) {
    // Generate first observation
    const recent = videos.slice(-5);
    try {
      const res = await fetch(`${apiBase}/api/echo/proactive`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${stored.syncToken}`,
        },
        body: JSON.stringify({
          recentVideos: recent.map(v => ({
            title: v.title,
            channel: v.channel,
            completionPercent: v.completionPercent || 0,
            skipped: (v.completionPercent || 0) < 20,
          })),
          totalVideosToday: videos.length,
          skippedCount: recent.filter(v => (v.completionPercent || 0) < 20).length,
          isFirstObservation: true,
        }),
      });

      if (res.ok) {
        const data = await res.json();
        if (data.message) {
          chrome.runtime.sendMessage({ type: "proactive_message", text: data.message }).catch(() => {});
          youtubeState.lastProactiveTime = now;
          await chrome.storage.local.set({ isFirstSession: false, sessionCount: 1 });
        }
      }
    } catch (err) {
      console.error("[Attune] First observation error:", err);
    }
    return;
  }

  // ─── Normal proactive triggers ───
  if (videos.length < 3) return;

  const recent = videos.slice(-5);
  const skippedCount = recent.filter(v => (v.completionPercent || 0) < 20).length;
  const shouldTrigger = skippedCount >= 3 || videos.length % 5 === 0;
  if (!shouldTrigger) return;

  try {
    const res = await fetch(`${apiBase}/api/echo/proactive`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${stored.syncToken}`,
      },
      body: JSON.stringify({
        recentVideos: recent.map(v => ({
          title: v.title,
          channel: v.channel,
          completionPercent: v.completionPercent || 0,
          skipped: (v.completionPercent || 0) < 20,
        })),
        totalVideosToday: videos.length,
        skippedCount,
      }),
    });

    if (res.ok) {
      const data = await res.json();
      if (data.message) {
        chrome.runtime.sendMessage({ type: "proactive_message", text: data.message }).catch(() => {});
        youtubeState.lastProactiveTime = now;
      }
    }
  } catch (err) {
    console.error("[Attune] Proactive message error:", err);
  }
}
```

- [ ] **Step 4: Update proactive API for first observation**

In `web/src/app/api/echo/proactive/route.ts`, add first observation handling. Update the prompt construction:

```typescript
  const isFirst = body.isFirstObservation;

  const prompt = isFirst
    ? `You are Echo, meeting this user for the first time. You've been silently watching them browse YouTube. Here are the first ${recentVideos.length} videos they've interacted with:

${videoList}

Make your FIRST observation about them. Be specific, not generic. Show that you were actually paying attention. One sentence, casual tone, like a friend who just formed a first impression.

Example: "You skipped three cooking videos but watched that entire 20-minute video essay. You're not here to learn recipes, are you?"

Respond with ONLY the observation.`
    : /* existing prompt */;
```

- [ ] **Step 5: Verify — test cold start flow**

1. Clear extension storage (chrome://extensions → Details → Clear storage)
2. Reload extension
3. Open Side Panel → enter sync token
4. Should see: "Hey — I'm Echo. I just got here..."
5. Open YouTube, watch/skip 3+ videos
6. After 3rd video, Echo should send a first observation message
7. Message should be specific to what was actually watched

- [ ] **Step 6: Commit**

```bash
git add extension/src/sidepanel.js extension/src/background.js web/src/app/api/echo/proactive/route.ts
git commit -m "feat: cold start experience — Echo introduction and first observation"
```

---

## Task 7: Polish & Integration

**Files:**
- Modify: `extension/src/background.js`
- Modify: `extension/src/sidepanel.js`
- Modify: `extension/src/popup.html`

### Wire everything together, handle edge cases, update branding.

- [ ] **Step 1: Clean up background.js imports and console logs**

Update the console log at the bottom of background.js:

```javascript
console.log("[Attune] Extension loaded — perception engine started");
```

Replace all `[ToDay]` log prefixes with `[Attune]`.

- [ ] **Step 2: Handle side panel reopening gracefully**

In `sidepanel.js`, when the Side Panel is reopened, it should restore state and request context update:

The current `init()` already handles this via `chrome.storage.local.get`. Add after `setupMessageBus()`:

```javascript
  // Request context update from background on (re)open
  setTimeout(() => {
    chrome.runtime.sendMessage({ type: "get_context" }).catch(() => {});
  }, 500);
```

- [ ] **Step 3: Add session end summary**

In `sidepanel.js`, listen for when the user is about to close the browser or the extension is going to sleep. Not feasible in MV3 service workers — skip this for MVP.

- [ ] **Step 4: Update popup.html fully with Attune branding**

Ensure all references in popup.html are updated:
- Title: "Attune"
- Logo: "Attune." (not "ToDay.")
- Footer: "Attune" (not "ToDay Browser Extension")

- [ ] **Step 5: Handle API errors gracefully in Side Panel**

In `sidepanel.js`, the `streamEchoResponse` catch block already shows a friendly message. Verify it works when:
- API is down → "Sorry, I couldn't connect right now."
- Token is invalid → should show error

- [ ] **Step 6: Add basic conversation persistence to cloud**

In `sidepanel.js`, after each echo response, save the last few messages to the server for cross-device access. Add after `saveMessages()`:

```javascript
async function syncConversationToCloud() {
  if (!state.syncToken) return;
  try {
    // Save last 20 messages to memory as conversation context
    const recent = state.messages.slice(-20);
    await fetch(`${state.apiBaseUrl}/api/memory`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${state.syncToken}`,
      },
      body: JSON.stringify({
        memory_type: "note",
        content: {
          text: `Recent conversation (${new Date().toLocaleDateString()}): ${recent.map(m => `[${m.role}] ${m.text.slice(0, 100)}`).join(" | ")}`,
        },
      }),
    });
  } catch {}
}
```

Call this at the end of `streamEchoResponse` after a successful response.

- [ ] **Step 7: Final verification — end-to-end test**

1. Load extension fresh
2. Open Side Panel → connect with sync token
3. See Echo's welcome message
4. Open YouTube → watch a video
5. Side Panel context bar shows "Watching: [title]"
6. Ask Echo: "what am I watching?" → Echo should mention the video
7. Watch/skip 3+ videos → Echo should proactively say something
8. Switch to Timeline tab → see today's browsing history
9. Toggle quiet mode → Echo should stop proactive messages
10. Close and reopen Side Panel → messages should be restored

- [ ] **Step 8: Commit**

```bash
git add extension/ web/
git commit -m "feat: Attune MVP integration — end-to-end Echo companion experience"
```

---

## Self-Review Checklist

### Spec Coverage
| Spec Requirement | Task |
|---|---|
| Side Panel UI | Task 1 |
| YouTube content script (title, channel, video ID, watch progress, completion) | Task 2 |
| Universal basic perception (tabs, idle, search keywords) | Task 4 |
| Echo conversation in Side Panel | Task 1 (shell) + Task 3 (API) |
| Echo proactive messaging | Task 2 (triggers) + Task 3 (API) + Task 6 (cold start) |
| Recording/Timeline | Task 1 (timeline tab) |
| Memory system | Task 5 |
| Memory management (view/delete/reset) | Task 5 (API), Side Panel memory view deferred to post-MVP polish |
| Account system | Existing + Task 1 (sync token flow) |
| Cold start experience | Task 6 |
| Quiet mode | Task 1 (toggle in UI) |
| Context bar | Task 1 (UI) + Task 2 (data flow) |
| Branding (Attune) | Task 1 + Task 7 |

### Gap: Memory Management UI
The "Echo's Memory" page where users can view/delete Echo's knowledge is not fully implemented as a Side Panel view. The API (Task 5) supports CRUD, but the UI for viewing memories in the Side Panel is deferred to a follow-up task. This is acceptable for MVP — the core experience (Echo chat + YouTube perception + proactive messages) is complete.

### Gap: Hot Comments Extraction
Spec mentions extracting top YouTube comments. Deferred — YouTube comment DOM is fragile and adds complexity. The core experience works without it.

### Gap: webNavigation (arrived via search/direct/link)
Mentioned in spec Tier 2 perception. The permission is added to manifest but the handler is not implemented. Can be added in a follow-up. Search keyword extraction from URLs covers the most important use case.

---

## Execution Summary

| Task | What It Builds | Files |
|---|---|---|
| 1 | Side Panel shell, tabs, auth, timeline, branding | manifest, sidepanel.*, popup.* |
| 2 | YouTube content script + background handler | youtube.js, background.js |
| 3 | Context-aware Echo API + proactive endpoint | chat/route.ts, proactive/route.ts |
| 4 | Search keywords, tab behavior, rich context | background.js |
| 5 | Memory database + API + chat integration | migration, memory/route.ts, chat/route.ts |
| 6 | Cold start welcome + first observation | sidepanel.js, background.js, proactive/route.ts |
| 7 | Polish, edge cases, e2e verification | Various |
