// ─── Attune Side Panel Controller ───

const DEFAULT_API_BASE = "https://daycho.com";
function getWelcomeMessage() {
  const lang = navigator.language || "en";
  if (lang.startsWith("zh")) {
    return "嘿，我是 Echo。刚到这儿，还不了解你。你先随便逛，我在旁边看着。刷几个视频我就开始有感觉了。";
  }
  return "Hey \u2014 I'm Echo. I just got here, so I don't know you yet. Go do your thing, I'll be watching. Give me a few videos and I'll start to get a sense of you.";
}
const MAX_STORED_MESSAGES = 100;

// ─── State ───

const state = {
  connected: false,
  syncToken: null,
  apiBaseUrl: DEFAULT_API_BASE,
  quietMode: false,
  messages: [],
  currentContext: null,
};

// ─── DOM References ───

const $ = (id) => document.getElementById(id);

const dom = {
  quietToggle: $("quietToggle"),
  contextBar: $("contextBar"),
  contextText: $("contextText"),
  echoTab: $("echoTab"),
  timelineTab: $("timelineTab"),
  setupScreen: $("setupScreen"),
  chatScreen: $("chatScreen"),
  messages: $("messages"),
  typingIndicator: $("typingIndicator"),
  inputBar: $("inputBar"),
  chatInput: $("chatInput"),
  sendBtn: $("sendBtn"),
  connectBtn: $("connectBtn"),
  setupToken: $("setupToken"),
  setupApiBase: $("setupApiBase"),
  timelineList: $("timelineList"),
};

// ─── Init ───

async function init() {
  const result = await chrome.storage.local.get([
    "syncToken",
    "apiBaseUrl",
    "quietMode",
    "echoMessages",
    "isFirstSession",
    "sessionCount",
  ]);

  state.syncToken = result.syncToken || null;
  state.apiBaseUrl = result.apiBaseUrl || DEFAULT_API_BASE;
  state.quietMode = result.quietMode || false;
  state.messages = result.echoMessages || [];
  state.connected = !!state.syncToken;
  state.isFirstSession = result.isFirstSession !== undefined ? result.isFirstSession : true;
  state.sessionCount = result.sessionCount || 0;

  renderAuthState();
  setupListeners();
  setupMessageBus();

  if (state.quietMode) {
    dom.quietToggle.classList.add("active");
  }

  // Request current context from background
  chrome.runtime.sendMessage({ type: "get_context" });

  // Delayed re-request ensures context bar updates when Side Panel is reopened
  setTimeout(() => {
    chrome.runtime.sendMessage({ type: "get_context" }).catch(() => {});
  }, 500);
}

// ─── Auth State Rendering ───

function renderAuthState() {
  if (state.connected) {
    showChat();
  } else {
    showSetup();
  }
}

function showSetup() {
  dom.setupScreen.classList.remove("hidden");
  dom.chatScreen.classList.add("hidden");
  dom.inputBar.classList.add("hidden");
  dom.setupApiBase.value = state.apiBaseUrl;
}

function showChat() {
  dom.setupScreen.classList.add("hidden");
  dom.chatScreen.classList.remove("hidden");
  dom.inputBar.classList.remove("hidden");

  // Render existing messages
  dom.messages.innerHTML = "";
  state.messages.forEach((msg) => {
    const el = createMessageElement(msg);
    dom.messages.appendChild(el);
  });

  scrollToBottom();
}

// ─── Setup / Connect ───

function setupListeners() {
  // Connect button
  dom.connectBtn.addEventListener("click", handleConnect);

  // Tab switching
  document.querySelectorAll(".tab").forEach((tab) => {
    tab.addEventListener("click", () => switchTab(tab.dataset.tab));
  });

  // Send message
  dom.sendBtn.addEventListener("click", sendMessage);
  dom.chatInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  });

  // Auto-resize textarea
  dom.chatInput.addEventListener("input", () => {
    dom.chatInput.style.height = "auto";
    dom.chatInput.style.height = Math.min(dom.chatInput.scrollHeight, 120) + "px";
  });

  // Quiet mode toggle
  dom.quietToggle.addEventListener("click", toggleQuietMode);
}

async function handleConnect() {
  const token = dom.setupToken.value.trim();
  if (!token) return;

  const apiBase = dom.setupApiBase.value.trim() || DEFAULT_API_BASE;

  state.syncToken = token;
  state.apiBaseUrl = apiBase;
  state.connected = true;

  await chrome.storage.local.set({
    syncToken: token,
    apiBaseUrl: apiBase,
    isFirstSession: true,
    sessionCount: 0,
  });

  state.isFirstSession = true;
  state.sessionCount = 0;

  // Add welcome message on first connect
  if (state.messages.length === 0) {
    addEchoMessage(getWelcomeMessage());
  }

  showChat();
}

// ─── Tab Switching ───

function switchTab(tabName) {
  document.querySelectorAll(".tab").forEach((t) => t.classList.remove("active"));
  document.querySelector(`.tab[data-tab="${tabName}"]`).classList.add("active");

  if (tabName === "echo") {
    dom.echoTab.classList.remove("hidden");
    dom.timelineTab.classList.add("hidden");
    if (state.connected) {
      dom.inputBar.classList.remove("hidden");
    }
  } else {
    dom.echoTab.classList.add("hidden");
    dom.timelineTab.classList.remove("hidden");
    dom.inputBar.classList.add("hidden");
    renderTimeline();
  }
}

// ─── Message Bus ───

function setupMessageBus() {
  chrome.runtime.onMessage.addListener((message) => {
    if (message.type === "context_update") {
      updateContextBar(message.data);
    } else if (message.type === "proactive_message") {
      if (!state.quietMode) {
        addProactiveMessage(message.text);
      }
    }
  });
}

// ─── Context Bar ───

function updateContextBar(context) {
  if (!context || (!context.domain && !context.title)) {
    dom.contextBar.classList.add("hidden");
    state.currentContext = null;
    return;
  }

  state.currentContext = context;
  dom.contextText.textContent = context.title || context.domain;
  dom.contextBar.classList.remove("hidden");
}

// ─── Chat ───

async function sendMessage() {
  const text = dom.chatInput.value.trim();
  if (!text) return;

  dom.chatInput.value = "";
  dom.chatInput.style.height = "auto";

  addUserMessage(text);
  showTypingIndicator();

  try {
    await streamEchoResponse(text);
  } catch (err) {
    console.error("[Attune] Chat error:", err);
    addEchoMessage("Sorry, I couldn't connect. Check your settings and try again.");
  }

  hideTypingIndicator();
}

async function streamEchoResponse(userText) {
  const apiUrl = `${state.apiBaseUrl}/api/echo/chat`;

  // Build messages array from conversation history
  const recentMessages = state.messages.slice(-20).map((m) => ({
    role: m.role === "user" ? "user" : "assistant",
    content: m.text,
  }));
  // Add the new user message
  recentMessages.push({ role: "user", content: userText });

  const body = {
    messages: recentMessages,
    context: state.currentContext || undefined,
    lang: navigator.language || "en",
    localTime: new Date().toLocaleString(),
    localHour: new Date().getHours(),
  };

  const res = await fetch(apiUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${state.syncToken}`,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    throw new Error(`API responded with ${res.status}`);
  }

  // Stream SSE response
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let fullText = "";
  let messageEl = null;

  hideTypingIndicator();

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    const chunk = decoder.decode(value, { stream: true });
    const lines = chunk.split("\n");

    for (const line of lines) {
      if (line.startsWith("data: ")) {
        const data = line.slice(6);

        if (data === "[DONE]") break;

        try {
          const parsed = JSON.parse(data);
          const content =
            parsed.choices?.[0]?.delta?.content ||
            parsed.delta?.content ||
            parsed.content ||
            "";

          if (content) {
            fullText += content;

            if (!messageEl) {
              messageEl = createStreamingMessage();
              dom.messages.appendChild(messageEl);
            }

            messageEl.querySelector(".message-bubble").textContent = fullText;
            scrollToBottom();
          }
        } catch {
          // Non-JSON data line, try as plain text
          if (data.trim()) {
            fullText += data;
            if (!messageEl) {
              messageEl = createStreamingMessage();
              dom.messages.appendChild(messageEl);
            }
            messageEl.querySelector(".message-bubble").textContent = fullText;
            scrollToBottom();
          }
        }
      }
    }
  }

  if (fullText) {
    // Add timestamp to the completed message
    if (messageEl) {
      const timeEl = document.createElement("div");
      timeEl.className = "message-time";
      timeEl.textContent = formatTime(Date.now());
      messageEl.appendChild(timeEl);
    }

    // Save to state
    const msg = {
      role: "echo",
      text: fullText,
      timestamp: Date.now(),
    };
    state.messages.push(msg);
    persistMessages();

    // Sync conversation summary to cloud for cross-device access
    syncConversationToCloud();
  }
}

function createStreamingMessage() {
  const el = document.createElement("div");
  el.className = "message echo";
  const bubble = document.createElement("div");
  bubble.className = "message-bubble";
  el.appendChild(bubble);
  return el;
}

// ─── Conversation Cloud Sync ───

async function syncConversationToCloud() {
  if (!state.syncToken) return;
  try {
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

// ─── Message Rendering ───

function addUserMessage(text) {
  const msg = { role: "user", text, timestamp: Date.now() };
  state.messages.push(msg);

  const el = createMessageElement(msg);
  dom.messages.appendChild(el);
  scrollToBottom();
  persistMessages();
}

function addEchoMessage(text) {
  const msg = { role: "echo", text, timestamp: Date.now() };
  state.messages.push(msg);

  const el = createMessageElement(msg);
  dom.messages.appendChild(el);
  scrollToBottom();
  persistMessages();
}

function addProactiveMessage(text) {
  const msg = { role: "proactive", text, timestamp: Date.now() };
  state.messages.push(msg);

  const el = createMessageElement(msg);
  dom.messages.appendChild(el);
  scrollToBottom();
  persistMessages();
}

function createMessageElement(msg) {
  const el = document.createElement("div");
  const roleClass =
    msg.role === "user" ? "user" : msg.role === "proactive" ? "proactive" : "echo";
  el.className = `message ${roleClass}`;

  const bubble = document.createElement("div");
  bubble.className = "message-bubble";
  bubble.textContent = msg.text;
  el.appendChild(bubble);

  const time = document.createElement("div");
  time.className = "message-time";
  time.textContent = formatTime(msg.timestamp);
  el.appendChild(time);

  return el;
}

// ─── Utilities ───

function scrollToBottom() {
  const chatScreen = dom.chatScreen;
  if (chatScreen) {
    chatScreen.scrollTop = chatScreen.scrollHeight;
  }
}

function showTypingIndicator() {
  dom.typingIndicator.classList.remove("hidden");
  scrollToBottom();
}

function hideTypingIndicator() {
  dom.typingIndicator.classList.add("hidden");
}

function formatTime(timestamp) {
  const d = new Date(timestamp);
  return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function formatDuration(seconds) {
  if (seconds < 60) return `${seconds}s`;
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

// ─── Persistence ───

async function persistMessages() {
  // Keep only the last MAX_STORED_MESSAGES
  const toSave = state.messages.slice(-MAX_STORED_MESSAGES);
  state.messages = toSave;
  await chrome.storage.local.set({ echoMessages: toSave });
}

// ─── Quiet Mode ───

function toggleQuietMode() {
  state.quietMode = !state.quietMode;
  dom.quietToggle.classList.toggle("active", state.quietMode);
  chrome.storage.local.set({ quietMode: state.quietMode });
}

// ─── Timeline ───

async function renderTimeline() {
  const todayKey = new Date().toISOString().split("T")[0];
  const result = await chrome.storage.local.get(["sessions", "currentSession"]);
  const closedSessions = result.sessions?.[todayKey] || [];

  const allSessions = [...closedSessions];
  if (result.currentSession) {
    const now = Date.now();
    const duration = Math.round((now - result.currentSession.startTime) / 1000);
    if (duration >= 10) {
      allSessions.push({
        ...result.currentSession,
        endTime: now,
        duration,
      });
    }
  }

  // Sort newest first
  allSessions.sort((a, b) => b.startTime - a.startTime);

  if (allSessions.length === 0) {
    dom.timelineList.innerHTML =
      '<div class="timeline-empty">No browsing activity yet today.</div>';
    return;
  }

  dom.timelineList.innerHTML = allSessions
    .map(
      (session) => `
    <div class="timeline-item">
      <span class="timeline-time">${formatTime(session.startTime)}</span>
      <div class="timeline-info">
        <div class="timeline-domain">${escapeHtml(session.label || session.domain)}</div>
        <div class="timeline-title">${escapeHtml(session.title || "")}</div>
      </div>
      <span class="timeline-duration">${formatDuration(session.duration || 0)}</span>
    </div>
  `
    )
    .join("");
}

function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

// ─── Start ───

init();
