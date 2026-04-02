import { categorize } from "./categories.js";

// ─── Side Panel Behavior ───

chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: false });

// ─── Configuration ───

const HEARTBEAT_INTERVAL = 10; // seconds
const SYNC_INTERVAL = 1; // minutes
const IDLE_THRESHOLD = 120; // seconds
const DEFAULT_API_BASE = "https://to-day-ten.vercel.app";

// ─── State Management ───

async function getState() {
  const result = await chrome.storage.local.get([
    "currentSession",
    "sessions",
    "lastSync",
    "isIdle",
    "trackingEnabled",
    "lastSyncedCount",
    "syncToken",
    "apiBaseUrl",
  ]);
  return {
    currentSession: result.currentSession || null,
    sessions: result.sessions || {},
    lastSync: result.lastSync || null,
    isIdle: result.isIdle || false,
    trackingEnabled: result.trackingEnabled !== false,
    lastSyncedCount: result.lastSyncedCount || {},
    syncToken: result.syncToken || null,
    apiBaseUrl: result.apiBaseUrl || DEFAULT_API_BASE,
  };
}

async function saveState(updates) {
  await chrome.storage.local.set(updates);
}

// ─── Idle Detection ───

chrome.idle.setDetectionInterval(IDLE_THRESHOLD);

chrome.idle.onStateChanged.addListener(async (state) => {
  if (state === "idle" || state === "locked") {
    await closeCurrentSession("idle");
    await saveState({ isIdle: true });
    console.log("[Attune] User idle — tracking paused");
  } else if (state === "active") {
    await saveState({ isIdle: false });
    heartbeat();
    console.log("[Attune] User active — tracking resumed");
  }
});

// ─── Window Focus Detection ───

chrome.windows.onFocusChanged.addListener(async (windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE) {
    await closeCurrentSession("blur");
  } else {
    heartbeat();
  }
});

// ─── Session-Based Tracking ───

async function heartbeat() {
  try {
    const state = await getState();

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

    if (state.currentSession && state.currentSession.domain === domain) {
      const gap = now - state.currentSession.endTime;
      if (gap > 5 * 60 * 1000) {
        await closeCurrentSession("stale");
        await startNewSession({ domain, label, category, title, now, todayKey, state });
      } else {
        state.currentSession.endTime = now;
        if (title && title !== state.currentSession.title) {
          state.currentSession.title = title;
        }
        await saveState({ currentSession: state.currentSession });
      }
      return;
    }

    await closeCurrentSession("switch");
    await startNewSession({ domain, label, category, title, now, todayKey, state });
  } catch (e) {
    console.error("[Attune] Heartbeat error:", e);
  }
}

async function startNewSession({ domain, label, category, title, now }) {
  const newSession = {
    domain,
    label,
    category,
    title,
    startTime: now,
    endTime: now,
  };

  await saveState({ currentSession: newSession });
}

async function closeCurrentSession(reason) {
  const state = await getState();
  if (!state.currentSession) return;

  const todayKey = new Date(state.currentSession.startTime).toISOString().split("T")[0];
  const todaySessions = state.sessions[todayKey] || [];
  const duration = Math.round((state.currentSession.endTime - state.currentSession.startTime) / 1000);

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

// ─── Incremental Data Sync ───

async function syncToServer() {
  try {
    const state = await getState();

    // Skip if no sync token configured
    if (!state.syncToken) {
      console.log("[Attune] No sync token — skipping server sync");
      return;
    }

    const todayKey = new Date().toISOString().split("T")[0];
    const todaySessions = state.sessions[todayKey] || [];

    // Include current active session
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

    // Incremental: only send new sessions since last sync
    const lastCount = state.lastSyncedCount[todayKey] || 0;
    const newSessions = allSessions.slice(lastCount);

    if (newSessions.length === 0) return;

    const apiUrl = `${state.apiBaseUrl}/api/sessions`;

    try {
      const res = await fetch(apiUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${state.syncToken}`,
        },
        body: JSON.stringify({ sessions: newSessions }),
      });

      if (res.ok) {
        // Update synced count on success
        await saveState({
          lastSync: Date.now(),
          lastSyncedCount: {
            ...state.lastSyncedCount,
            [todayKey]: allSessions.length,
          },
        });
        console.log(`[Attune] Synced ${newSessions.length} new sessions`);
      } else {
        console.warn(`[Attune] Sync failed: ${res.status}`);
      }
    } catch {
      // Server unavailable — will retry next cycle
    }
  } catch (e) {
    console.error("[Attune] Sync error:", e);
  }
}

// ─── Local Cache Cleanup ───

async function cleanup() {
  const state = await getState();
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 30);
  const cutoffKey = cutoff.toISOString().split("T")[0];

  const cleaned = {};
  for (const [key, sessions] of Object.entries(state.sessions)) {
    if (key >= cutoffKey) {
      cleaned[key] = sessions;
    }
  }

  // Also clean old lastSyncedCount entries
  const cleanedCount = {};
  for (const [key, count] of Object.entries(state.lastSyncedCount)) {
    if (key >= cutoffKey) {
      cleanedCount[key] = count;
    }
  }

  await saveState({ sessions: cleaned, lastSyncedCount: cleanedCount });
}

// ─── Alarms ───

chrome.alarms.create("heartbeat", { periodInMinutes: HEARTBEAT_INTERVAL / 60 });
chrome.alarms.create("sync", { periodInMinutes: SYNC_INTERVAL });
chrome.alarms.create("cleanup", { periodInMinutes: 60 });

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "heartbeat") heartbeat();
  if (alarm.name === "sync") syncToServer();
  if (alarm.name === "cleanup") cleanup();
});

chrome.tabs.onActivated.addListener(() => heartbeat());
chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "complete") heartbeat();
});

heartbeat();

// ─── Message Listener (Side Panel) ───

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === "get_context") {
    (async () => {
      const state = await getState();
      const context = state.currentSession
        ? {
            domain: state.currentSession.domain,
            title: state.currentSession.title,
            category: state.currentSession.category,
            label: state.currentSession.label,
          }
        : null;

      // Broadcast context_update to all extension pages (side panel)
      chrome.runtime.sendMessage({
        type: "context_update",
        data: context,
      }).catch(() => {
        // No listeners — that's fine
      });
    })();
    return false;
  }
});

console.log("[Attune] Extension loaded — session tracking started");
