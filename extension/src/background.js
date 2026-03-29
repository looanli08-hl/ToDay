import { categorize } from "./categories.js";

// Configuration
const HEARTBEAT_INTERVAL = 15; // seconds
const SYNC_INTERVAL = 5; // minutes
const API_URL = "http://localhost:3001/api/data";

// ─── State Management (chrome.storage because service workers are non-persistent) ───

async function getState() {
  const result = await chrome.storage.local.get(["currentSite", "todayData", "lastSync"]);
  return {
    currentSite: result.currentSite || null,
    todayData: result.todayData || {},
    lastSync: result.lastSync || null,
  };
}

async function saveState(updates) {
  await chrome.storage.local.set(updates);
}

// ─── Heartbeat Logic ───

async function heartbeat() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    if (!tab || !tab.url || tab.url.startsWith("chrome://") || tab.url.startsWith("chrome-extension://")) {
      // Browser internal page — stop tracking
      await saveState({ currentSite: null });
      return;
    }

    const url = tab.url;
    const title = tab.title || "";
    const domain = new URL(url).hostname.replace(/^www\./, "");
    const { category, label } = categorize(url);
    const now = Date.now();

    const state = await getState();
    const todayKey = new Date().toISOString().split("T")[0]; // "2026-03-29"
    const todayData = state.todayData[todayKey] || {};

    // If same domain as before, add heartbeat interval to duration
    if (state.currentSite && state.currentSite.domain === domain) {
      const existing = todayData[domain] || { domain, label, category, duration: 0, title };
      existing.duration += HEARTBEAT_INTERVAL;
      existing.title = title; // Update to latest title
      todayData[domain] = existing;
    } else {
      // New site — start tracking
      const existing = todayData[domain] || { domain, label, category, duration: 0, title };
      existing.duration += HEARTBEAT_INTERVAL;
      existing.title = title;
      todayData[domain] = existing;
    }

    await saveState({
      currentSite: { domain, url, title, category, label, startedAt: state.currentSite?.domain === domain ? state.currentSite.startedAt : now },
      todayData: { ...state.todayData, [todayKey]: todayData },
    });
  } catch (e) {
    console.error("[ToDay] Heartbeat error:", e);
  }
}

// ─── Data Sync ───

async function syncToServer() {
  try {
    const state = await getState();
    const todayKey = new Date().toISOString().split("T")[0];
    const todayData = state.todayData[todayKey];

    if (!todayData || Object.keys(todayData).length === 0) return;

    // Send each domain's data as a data point
    const entries = Object.values(todayData).filter(e => e.duration >= 30); // Min 30 seconds

    for (const entry of entries) {
      try {
        await fetch(API_URL, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            source: "browser-extension",
            type: "screenTime",
            value: entry,
            timestamp: new Date().toISOString(),
          }),
        });
      } catch {
        // Server might not be running — that's OK
      }
    }

    await saveState({ lastSync: Date.now() });
  } catch (e) {
    console.error("[ToDay] Sync error:", e);
  }
}

// ─── Alarms (periodic heartbeat + sync) ───

chrome.alarms.create("heartbeat", { periodInMinutes: HEARTBEAT_INTERVAL / 60 });
chrome.alarms.create("sync", { periodInMinutes: SYNC_INTERVAL });

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "heartbeat") heartbeat();
  if (alarm.name === "sync") syncToServer();
});

// Also heartbeat on tab changes
chrome.tabs.onActivated.addListener(() => heartbeat());
chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "complete") heartbeat();
});

// Initial heartbeat
heartbeat();

console.log("[ToDay] Extension loaded — tracking started");
