import { categorize } from "./categories.js";

// Configuration
const HEARTBEAT_INTERVAL = 15; // seconds
const SYNC_INTERVAL = 1; // minutes
const API_URL = "http://localhost:3001/api/data";

// ─── State Management ───

async function getState() {
  const result = await chrome.storage.local.get(["currentSession", "sessions", "lastSync"]);
  return {
    currentSession: result.currentSession || null,
    sessions: result.sessions || {},
    lastSync: result.lastSync || null,
  };
}

async function saveState(updates) {
  await chrome.storage.local.set(updates);
}

// ─── Session-Based Tracking ───
// Each website visit is a "session" with a start time and end time.
// When the user switches to a different domain, the current session ends
// and a new one begins.

async function heartbeat() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    if (!tab || !tab.url || tab.url.startsWith("chrome://") || tab.url.startsWith("chrome-extension://")) {
      // Close current session if on internal page
      await closeCurrentSession();
      return;
    }

    const url = tab.url;
    const title = tab.title || "";
    const domain = new URL(url).hostname.replace(/^www\./, "");
    const { category, label } = categorize(url);
    const now = Date.now();
    const state = await getState();
    const todayKey = new Date().toISOString().split("T")[0];

    // Same domain — extend current session
    if (state.currentSession && state.currentSession.domain === domain) {
      state.currentSession.endTime = now;
      state.currentSession.title = title;
      await saveState({ currentSession: state.currentSession });
      return;
    }

    // Different domain — close old session, start new one
    const todaySessions = state.sessions[todayKey] || [];

    // Close previous session
    if (state.currentSession) {
      const duration = Math.round((state.currentSession.endTime - state.currentSession.startTime) / 1000);
      if (duration >= 10) {
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
    }

    // Start new session
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
      sessions: { ...state.sessions, [todayKey]: todaySessions },
    });
  } catch (e) {
    console.error("[ToDay] Heartbeat error:", e);
  }
}

async function closeCurrentSession() {
  const state = await getState();
  if (!state.currentSession) return;

  const now = Date.now();
  const todayKey = new Date().toISOString().split("T")[0];
  const todaySessions = state.sessions[todayKey] || [];
  const duration = Math.round((now - state.currentSession.startTime) / 1000);

  if (duration >= 10) {
    todaySessions.push({
      domain: state.currentSession.domain,
      label: state.currentSession.label,
      category: state.currentSession.category,
      title: state.currentSession.title,
      startTime: state.currentSession.startTime,
      endTime: now,
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
    // Close current session temporarily to include it
    const state = await getState();
    const todayKey = new Date().toISOString().split("T")[0];
    const todaySessions = state.sessions[todayKey] || [];

    // Build complete session list (closed + current active)
    const allSessions = [...todaySessions];
    if (state.currentSession) {
      const now = Date.now();
      const duration = Math.round((now - state.currentSession.startTime) / 1000);
      if (duration >= 10) {
        allSessions.push({
          ...state.currentSession,
          endTime: now,
          duration,
        });
      }
    }

    if (allSessions.length === 0) return;

    // Send all sessions as one batch
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

// ─── Alarms ───

chrome.alarms.create("heartbeat", { periodInMinutes: HEARTBEAT_INTERVAL / 60 });
chrome.alarms.create("sync", { periodInMinutes: SYNC_INTERVAL });

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "heartbeat") heartbeat();
  if (alarm.name === "sync") syncToServer();
});

// Also heartbeat on tab changes for instant detection
chrome.tabs.onActivated.addListener(() => heartbeat());
chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "complete") heartbeat();
});

// Initial heartbeat
heartbeat();

console.log("[ToDay] Extension loaded — session tracking started");
