import { categorize } from "./categories.js";

// ─── Side Panel Behavior ───

chrome.sidePanel.setPanelBehavior({ openPanelOnActionClick: false });

// ─── Configuration ───

const HEARTBEAT_INTERVAL = 10; // seconds
const SYNC_INTERVAL = 1; // minutes
const IDLE_THRESHOLD = 120; // seconds
const DEFAULT_API_BASE = "https://daycho.com";

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

    // Track search queries
    const search = extractSearchQuery(url);
    if (search) {
      tabBehavior.searches.push(search);
      if (tabBehavior.searches.length > 50) {
        tabBehavior.searches = tabBehavior.searches.slice(-50);
      }
      persistTabBehavior();
    }

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
      broadcastContext();
      return;
    }

    await closeCurrentSession("switch");
    await startNewSession({ domain, label, category, title, now, todayKey, state });
    broadcastContext();
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

// ─── Search Keyword Extraction ───

function extractSearchQuery(url) {
  try {
    const parsed = new URL(url);
    const params = parsed.searchParams;
    const queryKeys = ["q", "query", "wd", "keyword"];
    for (const key of queryKeys) {
      const value = params.get(key);
      if (value) {
        return { engine: parsed.hostname.replace(/^www\./, ""), query: value };
      }
    }
  } catch {
    // Invalid URL — ignore
  }
  return null;
}

// ─── Tab Behavior Tracking ───

let tabBehavior = {
  date: new Date().toISOString().split("T")[0],
  switchCount: 0,
  lastSwitchTime: 0,
  openTabCount: 0,
  searches: [],
};

// ─── Alarms ───

chrome.alarms.create("heartbeat", { periodInMinutes: HEARTBEAT_INTERVAL / 60 });
chrome.alarms.create("sync", { periodInMinutes: SYNC_INTERVAL });
chrome.alarms.create("cleanup", { periodInMinutes: 60 });

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "heartbeat") heartbeat();
  if (alarm.name === "sync") syncToServer();
  if (alarm.name === "cleanup") cleanup();
});

chrome.tabs.onActivated.addListener(async () => {
  tabBehavior.switchCount++;
  tabBehavior.lastSwitchTime = Date.now();
  try {
    const tabs = await chrome.tabs.query({ currentWindow: true });
    tabBehavior.openTabCount = tabs.length;
  } catch {
    // Query failed — keep previous count
  }
  persistTabBehavior();
  heartbeat();
});
chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "complete") heartbeat();
});

heartbeat();

// ─── YouTube Perception State ───

let youtubeState = {
  date: new Date().toISOString().split("T")[0],
  currentVideo: null,
  videosThisSession: [],
  lastProactiveTime: 0,
};

const PROACTIVE_COOLDOWN = 10 * 60 * 1000; // 10 minutes

// ─── Proactive Message Queue ───

let proactiveQueue = [];

function queueProactiveMessage(text) {
  proactiveQueue.push({ text, time: Date.now() });
  chrome.action.setBadgeText({ text: "•" });
  chrome.action.setBadgeBackgroundColor({ color: "#C4713E" });
  // Persist queue in case service worker restarts
  chrome.storage.local.set({ proactiveQueue });
}

// ─── State Persistence Helpers ───

async function persistYoutubeState() {
  await chrome.storage.local.set({ youtubeState });
}

async function persistTabBehavior() {
  await chrome.storage.local.set({ tabBehavior });
}

// ─── Rolling Day Summary ───

function buildDaySummary(todaySessions) {
  const videos = youtubeState.videosThisSession || [];
  const searches = tabBehavior.searches || [];
  const sessions = todaySessions || [];

  let summary = "";

  // Video summary
  if (videos.length > 0) {
    const completed = videos.filter((v) => v.completed).length;
    const skipped = videos.filter((v) => v.skipped).length;
    summary += `YouTube: ${videos.length} videos today (${completed} watched fully, ${skipped} skipped). `;
    summary += `Recent: ${videos
      .slice(-5)
      .map(
        (v) =>
          `"${v.title}" (${v.completed ? "watched" : v.skipped ? "skipped" : (v.completionPercent || 0) + "%"})`
      )
      .join(", ")}. `;
  }

  // Browsing summary from sessions
  if (sessions.length > 0) {
    const domainTime = {};
    for (const s of sessions) {
      const d = s.label || s.domain;
      domainTime[d] = (domainTime[d] || 0) + (s.duration || 0);
    }
    const sorted = Object.entries(domainTime)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5);
    if (sorted.length > 0) {
      summary += `Browsing: visited ${sessions.length} sites. Top: ${sorted
        .map(([d, t]) => `${d} (${Math.round(t / 60)}m)`)
        .join(", ")}. `;
    }
  }

  // Search summary
  if (searches.length > 0) {
    summary += `Searches: ${searches
      .slice(-5)
      .map((s) => `"${s.query}"`)
      .join(", ")}. `;
  }

  return summary;
}

function getTopDomains(sessions) {
  if (!sessions || sessions.length === 0) return [];
  const domainTime = {};
  for (const s of sessions) {
    const d = s.label || s.domain;
    domainTime[d] = (domainTime[d] || 0) + (s.duration || 0);
  }
  return Object.entries(domainTime)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([domain, seconds]) => ({ domain, minutes: Math.round(seconds / 60) }));
}

// ─── Daily Summary Trigger ───

async function checkDailySummaryTrigger() {
  const stored = await chrome.storage.local.get(["lastDailySummaryDate"]);
  const today = new Date().toISOString().split("T")[0];
  const hour = new Date().getHours();

  // Only trigger in the evening (after 8 PM) and only once per day
  if (hour < 20) return;
  if (stored.lastDailySummaryDate === today) return;

  const videos = youtubeState.videosThisSession || [];
  if (videos.length < 3) return; // Not enough data for a summary

  const settings = await chrome.storage.local.get(["syncToken", "apiBaseUrl", "quietMode"]);
  if (!settings.syncToken || settings.quietMode) return;

  const apiBase = settings.apiBaseUrl || DEFAULT_API_BASE;
  const todayKey = new Date().toISOString().split("T")[0];
  const sessionsData = await chrome.storage.local.get(["sessions"]);
  const todaySessions = sessionsData.sessions?.[todayKey] || [];

  try {
    const res = await fetch(`${apiBase}/api/echo/proactive`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${settings.syncToken}`,
      },
      body: JSON.stringify({
        recentVideos: videos.slice(-10).map((v) => ({
          title: v.title,
          channel: v.channel,
          completionPercent: v.completionPercent || 0,
          skipped: v.skipped || false,
        })),
        totalVideosToday: videos.length,
        skippedCount: videos.filter((v) => v.skipped).length,
        type: "daily_summary",
        daySummary: buildDaySummary(todaySessions),
        lang: navigator.language || "en",
      }),
    });

    if (res.ok) {
      const data = await res.json();
      if (data.message) {
        chrome.runtime
          .sendMessage({ type: "proactive_message", text: data.message })
          .catch(() => {});
        queueProactiveMessage(data.message);
        await chrome.storage.local.set({ lastDailySummaryDate: today });
      }
    }
  } catch {
    // API unavailable — will retry next evaluation
  }
}

// ─── YouTube Context Helpers ───

function respondWithContext() {
  const current = youtubeState.currentVideo;
  const recentVideos = youtubeState.videosThisSession.slice(-10);

  const tabContext = {
    tabSwitchCount: tabBehavior.switchCount,
    openTabs: tabBehavior.openTabCount,
    recentSearches: tabBehavior.searches.slice(-5).map((s) => s.query),
  };

  const context = current
    ? {
        type: "youtube",
        videoId: current.videoId,
        title: current.title,
        channel: current.channel,
        duration: current.duration,
        currentTime: current.currentTime,
        completionPercent: current.completionPercent,
        paused: current.paused,
        url: current.url,
        recentVideos,
        ...tabContext,
      }
    : tabContext;

  chrome.runtime
    .sendMessage({ type: "context_update", data: context })
    .catch(() => {
      // No listeners — that's fine
    });
}

function broadcastContext() {
  respondWithContext();
}

function extractTopicKeywords(title) {
  // Extract meaningful words from a video title (strip common noise)
  const noise = new Set(["the", "a", "an", "is", "are", "was", "were", "in", "on", "at", "to", "for", "of", "and", "or", "but", "with", "how", "why", "what", "when", "this", "that", "it", "my", "your", "i", "you", "we", "they", "do", "does", "did", "will", "can", "not", "no", "so", "just", "get", "got", "new", "from", "all", "about", "been", "have", "has", "had"]);
  return (title || "")
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 2 && !noise.has(w));
}

function detectTopicOverlap(videos) {
  // Check if same topic keywords appear in 3+ video titles
  const keywordCount = {};
  for (const v of videos) {
    const keywords = extractTopicKeywords(v.title);
    const unique = new Set(keywords);
    for (const kw of unique) {
      keywordCount[kw] = (keywordCount[kw] || 0) + 1;
    }
  }
  return Object.values(keywordCount).some((count) => count >= 3);
}

function detectSearchVideoMatch(videos, searches) {
  // Check if any video title matches a recent search query
  if (!searches || searches.length === 0) return false;
  const searchTerms = searches.slice(-10).flatMap((s) => extractTopicKeywords(s.query));
  const searchSet = new Set(searchTerms);
  for (const v of videos.slice(-5)) {
    const titleWords = extractTopicKeywords(v.title);
    if (titleWords.some((w) => searchSet.has(w))) return true;
  }
  return false;
}

async function evaluateProactiveTrigger() {
  const now = Date.now();

  const { quietMode, syncToken, apiBaseUrl, isFirstSession, sessionCount } =
    await chrome.storage.local
      .get(["quietMode", "syncToken", "apiBaseUrl", "isFirstSession", "sessionCount"])
      .then((r) => ({
        quietMode: r.quietMode || false,
        syncToken: r.syncToken || null,
        apiBaseUrl: r.apiBaseUrl || DEFAULT_API_BASE,
        isFirstSession: r.isFirstSession !== undefined ? r.isFirstSession : true,
        sessionCount: r.sessionCount || 0,
      }));

  if (quietMode || !syncToken) return;

  const videos = youtubeState.videosThisSession;

  // ─── First-session trigger: after exactly 3 videos, fire once ───
  if (isFirstSession === true && videos.length >= 3 && sessionCount === 0) {
    try {
      const res = await fetch(`${apiBaseUrl}/api/echo/proactive`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${syncToken}`,
        },
        body: JSON.stringify({
          recentVideos: videos.slice(-10),
          totalVideosToday: videos.length,
          skippedCount: videos.filter((v) => v.skipped).length,
          isFirstObservation: true,
          lang: navigator.language || "en",
        }),
      });

      if (res.ok) {
        const result = await res.json();
        if (result.message) {
          chrome.runtime
            .sendMessage({ type: "proactive_message", text: result.message })
            .catch(() => {});
          queueProactiveMessage(result.message);
        }
        // Mark first session complete
        await chrome.storage.local.set({
          isFirstSession: false,
          sessionCount: 1,
        });
        youtubeState.lastProactiveTime = now;
        persistYoutubeState();
      }
    } catch {
      // API unavailable — will retry next evaluation
    }
    return; // Skip normal trigger evaluation
  }

  // ─── Code layer filter (fast checks) ───
  if (now - youtubeState.lastProactiveTime < PROACTIVE_COOLDOWN) return;
  if (videos.length < 3) return;

  const lastFive = videos.slice(-5);
  const skippedCount = lastFive.filter((v) => v.skipped).length;

  const shouldTrigger =
    skippedCount >= 3 ||
    detectTopicOverlap(videos) ||
    detectSearchVideoMatch(videos, tabBehavior.searches) ||
    videos.length % 5 === 0;

  if (!shouldTrigger) return;

  // ─── AI layer: send full context for richer proactive messages ───
  const todayKey = new Date().toISOString().split("T")[0];
  const sessionsData = await chrome.storage.local.get(["sessions"]);
  const todaySessions = sessionsData.sessions?.[todayKey] || [];

  try {
    const res = await fetch(`${apiBaseUrl}/api/echo/proactive`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${syncToken}`,
      },
      body: JSON.stringify({
        recentVideos: videos.slice(-10),
        totalVideosToday: videos.length,
        skippedCount: videos.filter((v) => v.skipped).length,
        daySummary: buildDaySummary(todaySessions),
        lang: navigator.language || "en",
      }),
    });

    if (res.ok) {
      const result = await res.json();
      if (result.message) {
        chrome.runtime
          .sendMessage({ type: "proactive_message", text: result.message })
          .catch(() => {});
        queueProactiveMessage(result.message);
      }
      youtubeState.lastProactiveTime = now;
      persistYoutubeState();
    }
  } catch {
    // Endpoint unavailable — fail gracefully
  }
}

// ─── Message Listener (Side Panel + YouTube) ───

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === "get_context") {
    (async () => {
      // Deliver any queued proactive messages
      if (proactiveQueue.length > 0) {
        for (const msg of proactiveQueue) {
          chrome.runtime
            .sendMessage({ type: "proactive_message", text: msg.text })
            .catch(() => {});
        }
        proactiveQueue = [];
        chrome.action.setBadgeText({ text: "" });
        chrome.storage.local.set({ proactiveQueue: [] });
      }

      // Check daily summary trigger
      checkDailySummaryTrigger();

      // If YouTube video is active, include YouTube context
      if (youtubeState.currentVideo) {
        respondWithContext();
        return;
      }

      // Otherwise fall back to session context
      const state = await getState();
      const context = state.currentSession
        ? {
            domain: state.currentSession.domain,
            title: state.currentSession.title,
            category: state.currentSession.category,
            label: state.currentSession.label,
          }
        : null;

      chrome.runtime
        .sendMessage({ type: "context_update", data: context })
        .catch(() => {
          // No listeners — that's fine
        });
    })();
    return false;
  }

  if (message.type === "get_full_context") {
    (async () => {
      // Deliver any queued proactive messages
      if (proactiveQueue.length > 0) {
        for (const msg of proactiveQueue) {
          chrome.runtime
            .sendMessage({ type: "proactive_message", text: msg.text })
            .catch(() => {});
        }
        proactiveQueue = [];
        chrome.action.setBadgeText({ text: "" });
        chrome.storage.local.set({ proactiveQueue: [] });
      }

      // Check daily summary trigger
      checkDailySummaryTrigger();

      const todayKey = new Date().toISOString().split("T")[0];
      const stored = await chrome.storage.local.get(["sessions"]);
      const todaySessions = stored.sessions?.[todayKey] || [];

      // Build current context (same as respondWithContext but returned directly)
      const current = youtubeState.currentVideo;
      const recentVideos = youtubeState.videosThisSession.slice(-10);
      const tabContext = {
        tabSwitchCount: tabBehavior.switchCount,
        openTabs: tabBehavior.openTabCount,
        recentSearches: tabBehavior.searches.slice(-5).map((s) => s.query),
      };

      let currentContext;
      if (current) {
        currentContext = {
          type: "youtube",
          videoId: current.videoId,
          title: current.title,
          channel: current.channel,
          duration: current.duration,
          currentTime: current.currentTime,
          completionPercent: current.completionPercent,
          paused: current.paused,
          url: current.url,
          recentVideos,
          ...tabContext,
        };
      } else {
        const state = await getState();
        currentContext = state.currentSession
          ? {
              domain: state.currentSession.domain,
              title: state.currentSession.title,
              category: state.currentSession.category,
              label: state.currentSession.label,
              ...tabContext,
            }
          : tabContext;
      }

      sendResponse({
        currentContext,
        daySummary: buildDaySummary(todaySessions),
        videoCount: youtubeState.videosThisSession.length,
        topDomains: getTopDomains(todaySessions),
      });
    })();
    return true; // async response with sendResponse
  }

  if (message.type === "youtube_event") {
    const { event, data } = message;

    switch (event) {
      case "video_start":
        youtubeState.currentVideo = {
          videoId: data.videoId,
          title: data.title,
          channel: data.channel,
          duration: data.duration,
          currentTime: data.currentTime,
          completionPercent: data.completionPercent,
          paused: data.paused,
          url: data.url,
          timestamp: data.timestamp,
          completed: false,
          skipped: false,
        };
        youtubeState.videosThisSession.push({ ...youtubeState.currentVideo });
        persistYoutubeState();
        broadcastContext();
        break;

      case "video_progress":
        if (youtubeState.currentVideo) {
          youtubeState.currentVideo.currentTime = data.currentTime;
          youtubeState.currentVideo.completionPercent = data.completionPercent;
        }
        break;

      case "video_leave":
      case "video_ended": {
        if (youtubeState.currentVideo) {
          youtubeState.currentVideo.completionPercent = data.completionPercent;
          youtubeState.currentVideo.completed = data.completionPercent >= 85;
          youtubeState.currentVideo.skipped = data.completionPercent < 20;

          // Update the entry in videosThisSession
          const idx = youtubeState.videosThisSession.findLastIndex(
            (v) => v.videoId === youtubeState.currentVideo.videoId
          );
          if (idx !== -1) {
            youtubeState.videosThisSession[idx] = {
              ...youtubeState.currentVideo,
            };
          }

          persistYoutubeState();
          broadcastContext();
          evaluateProactiveTrigger();

          if (event === "video_leave") {
            youtubeState.currentVideo = null;
            persistYoutubeState();
          }
        }
        break;
      }

      case "video_pause":
        if (youtubeState.currentVideo) {
          youtubeState.currentVideo.paused = true;
        }
        break;

      case "video_play":
        if (youtubeState.currentVideo) {
          youtubeState.currentVideo.paused = false;
        }
        break;
    }

    return false;
  }
});

// ─── Restore Persisted State on Service Worker Startup ───

chrome.storage.local.get(["youtubeState", "tabBehavior", "proactiveQueue"]).then((stored) => {
  const today = new Date().toISOString().split("T")[0];
  if (stored.youtubeState && stored.youtubeState.date === today) {
    youtubeState = stored.youtubeState;
  }
  if (stored.tabBehavior && stored.tabBehavior.date === today) {
    tabBehavior = stored.tabBehavior;
  }
  if (stored.proactiveQueue && Array.isArray(stored.proactiveQueue) && stored.proactiveQueue.length > 0) {
    proactiveQueue = stored.proactiveQueue;
    chrome.action.setBadgeText({ text: "•" });
    chrome.action.setBadgeBackgroundColor({ color: "#C4713E" });
  }
});

console.log("[Attune] Extension loaded — session tracking started");
