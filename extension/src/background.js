import { categorize } from "./categories.js";

// ─── Configuration ───

const HEARTBEAT_INTERVAL = 10; // seconds (was 15 — more accurate)
const SYNC_INTERVAL = 1; // minutes
const IDLE_THRESHOLD = 120; // seconds — consider idle after 2 min of no input
const API_URL = "http://localhost:3001/api/data";

// ─── State Management ───

async function getState() {
  const result = await chrome.storage.local.get([
    "currentSession",
    "sessions",
    "lastSync",
    "isIdle",
    "trackingEnabled",
  ]);
  return {
    currentSession: result.currentSession || null,
    sessions: result.sessions || {},
    lastSync: result.lastSync || null,
    isIdle: result.isIdle || false,
    trackingEnabled: result.trackingEnabled !== false, // default true
  };
}

async function saveState(updates) {
  await chrome.storage.local.set(updates);
}

// ─── Idle Detection ───
// Pause tracking when user is away from computer

chrome.idle.setDetectionInterval(IDLE_THRESHOLD);

chrome.idle.onStateChanged.addListener(async (state) => {
  if (state === "idle" || state === "locked") {
    // User left — close current session
    await closeCurrentSession("idle");
    await saveState({ isIdle: true });
    console.log("[ToDay] User idle — tracking paused");
  } else if (state === "active") {
    // User returned — resume tracking
    await saveState({ isIdle: false });
    heartbeat();
    console.log("[ToDay] User active — tracking resumed");
  }
});

// ─── Window Focus Detection ───
// Pause when browser loses focus (user switched to native app)

chrome.windows.onFocusChanged.addListener(async (windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE) {
    // Browser lost focus — close current session
    await closeCurrentSession("blur");
  } else {
    // Browser regained focus — start new session
    heartbeat();
  }
});

// ─── Session-Based Tracking ───

async function heartbeat() {
  try {
    const state = await getState();

    // Don't track if disabled or idle
    if (!state.trackingEnabled || state.isIdle) return;

    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    if (
      !tab ||
      !tab.url ||
      tab.url.startsWith("chrome://") ||
      tab.url.startsWith("chrome-extension://") ||
      tab.url.startsWith("about:") ||
      tab.url.startsWith("edge://")
    ) {
      await closeCurrentSession("internal");
      return;
    }

    // Skip incognito tabs
    if (tab.incognito) {
      await closeCurrentSession("incognito");
      return;
    }

    const url = tab.url;
    const title = tab.title || "";
    const domain = new URL(url).hostname.replace(/^www\./, "");
    const { category, label } = categorize(url);
    const now = Date.now();
    const todayKey = new Date().toISOString().split("T")[0];

    // Same domain — extend current session, update title
    if (state.currentSession && state.currentSession.domain === domain) {
      // Check for stale session (gap > 5 min means user was likely away)
      const gap = now - state.currentSession.endTime;
      if (gap > 5 * 60 * 1000) {
        // Close stale session, start fresh
        await closeCurrentSession("stale");
        await startNewSession({ domain, label, category, title, now, todayKey, state });
      } else {
        state.currentSession.endTime = now;
        // Update title if it changed (e.g., navigated within same domain)
        if (title && title !== state.currentSession.title) {
          state.currentSession.title = title;
        }
        await saveState({ currentSession: state.currentSession });
      }
      return;
    }

    // Different domain — close old, start new
    await closeCurrentSession("switch");
    await startNewSession({ domain, label, category, title, now, todayKey, state });
  } catch (e) {
    console.error("[ToDay] Heartbeat error:", e);
  }
}

async function startNewSession({ domain, label, category, title, now, todayKey, state }) {
  const newSession = {
    domain,
    label,
    category,
    title,
    startTime: now,
    endTime: now,
  };

  await saveState({
    currentSession: newSession,
  });
}

async function closeCurrentSession(reason) {
  const state = await getState();
  if (!state.currentSession) return;

  const now = Date.now();
  const todayKey = new Date(state.currentSession.startTime).toISOString().split("T")[0];
  const todaySessions = state.sessions[todayKey] || [];
  const duration = Math.round((state.currentSession.endTime - state.currentSession.startTime) / 1000);

  // Only save sessions longer than 5 seconds
  if (duration >= 5) {
    todaySessions.push({
      domain: state.currentSession.domain,
      label: state.currentSession.label,
      category: state.currentSession.category,
      title: state.currentSession.title,
      startTime: state.currentSession.startTime,
      endTime: state.currentSession.endTime,
      duration,
    });
  }

  await saveState({
    currentSession: null,
    sessions: { ...state.sessions, [todayKey]: todaySessions },
  });
}

// ─── Data Sync ───

async function syncToServer() {
  try {
    const state = await getState();
    const todayKey = new Date().toISOString().split("T")[0];
    const todaySessions = state.sessions[todayKey] || [];

    // Include current active session in sync
    const allSessions = [...todaySessions];
    if (state.currentSession) {
      const now = Date.now();
      const duration = Math.round((now - state.currentSession.startTime) / 1000);
      if (duration >= 5) {
        allSessions.push({
          ...state.currentSession,
          endTime: now,
          duration,
        });
      }
    }

    if (allSessions.length === 0) return;

    try {
      await fetch(API_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          source: "browser-extension",
          type: "screenTime",
          value: { sessions: allSessions },
          timestamp: new Date().toISOString(),
        }),
      });
    } catch {
      // Server might not be running
    }

    await saveState({ lastSync: Date.now() });
  } catch (e) {
    console.error("[ToDay] Sync error:", e);
  }
}

// ─── Data Cleanup ───
// Remove sessions older than 7 days to prevent storage bloat

async function cleanup() {
  const state = await getState();
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 7);
  const cutoffKey = cutoff.toISOString().split("T")[0];

  const cleaned = {};
  for (const [key, sessions] of Object.entries(state.sessions)) {
    if (key >= cutoffKey) {
      cleaned[key] = sessions;
    }
  }

  await saveState({ sessions: cleaned });
}

// ─── Alarms ───

chrome.alarms.create("heartbeat", { periodInMinutes: HEARTBEAT_INTERVAL / 60 });
chrome.alarms.create("sync", { periodInMinutes: SYNC_INTERVAL });
chrome.alarms.create("cleanup", { periodInMinutes: 60 }); // hourly cleanup

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "heartbeat") heartbeat();
  if (alarm.name === "sync") syncToServer();
  if (alarm.name === "cleanup") cleanup();
});

// Tab change = instant heartbeat
chrome.tabs.onActivated.addListener(() => heartbeat());
chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "complete") heartbeat();
});

// Initial heartbeat
heartbeat();

console.log("[ToDay] Extension loaded — session tracking started");
