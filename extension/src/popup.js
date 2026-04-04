const DEFAULT_API_BASE = "https://daycho.com";

function formatDuration(seconds) {
  if (seconds < 60) return `${seconds}s`;
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

function formatTime(timestamp) {
  const d = new Date(timestamp);
  return d.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false });
}

async function render() {
  const todayKey = new Date().toISOString().split("T")[0];
  const result = await chrome.storage.local.get(["sessions", "currentSession", "syncToken"]);
  const closedSessions = result.sessions?.[todayKey] || [];

  // Include current active session
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

  // Sort by start time (newest first)
  allSessions.sort((a, b) => b.startTime - a.startTime);

  // Total time
  const totalSeconds = allSessions.reduce((sum, e) => sum + (e.duration || 0), 0);
  document.getElementById("totalTime").textContent = formatDuration(totalSeconds);

  // Update status indicator
  const statusDot = document.querySelector(".status-dot");
  const statusText = document.querySelector(".status span");
  if (result.syncToken) {
    statusDot.style.background = "#10b981";
    statusText.textContent = "已连接";
  } else {
    statusDot.style.background = "#f59e0b";
    statusText.textContent = "未同步";
  }

  // Render site list
  const siteList = document.getElementById("siteList");
  if (allSessions.length === 0) {
    siteList.innerHTML = '<div class="empty-state"><p>继续浏览，数据会自动出现</p></div>';
  } else {
    siteList.innerHTML = allSessions.map(session => `
      <div class="site-item">
        <span class="site-time-range">${formatTime(session.startTime)} - ${formatTime(session.endTime)}</span>
        <span class="site-name">${session.label || session.domain}</span>
        <span class="site-time">${formatDuration(session.duration || 0)}</span>
      </div>
    `).join("");
  }
}

// Settings toggle
let settingsVisible = false;
document.getElementById("settingsToggle").addEventListener("click", () => {
  settingsVisible = !settingsVisible;
  document.getElementById("settingsSection").style.display = settingsVisible ? "block" : "none";
  document.getElementById("settingsToggle").textContent = settingsVisible ? "收起" : "设置";
});

// Load saved settings
chrome.storage.local.get(["syncToken", "apiBaseUrl"], (result) => {
  document.getElementById("syncTokenInput").value = result.syncToken || "";
  document.getElementById("apiBaseInput").value = result.apiBaseUrl || DEFAULT_API_BASE;
});

// Save settings
document.getElementById("saveSettingsBtn").addEventListener("click", async () => {
  const syncToken = document.getElementById("syncTokenInput").value.trim();
  const apiBaseUrl = document.getElementById("apiBaseInput").value.trim() || DEFAULT_API_BASE;

  await chrome.storage.local.set({ syncToken: syncToken || null, apiBaseUrl });

  document.getElementById("saveStatus").textContent = "已保存";
  setTimeout(() => {
    document.getElementById("saveStatus").textContent = "";
  }, 2000);

  // Re-render to update status
  render();
});

// Open dashboard
document.getElementById("dashboardLink").addEventListener("click", async () => {
  const result = await chrome.storage.local.get(["apiBaseUrl"]);
  const base = result.apiBaseUrl || DEFAULT_API_BASE;
  chrome.tabs.create({ url: `${base}/dashboard` });
});

// Open Echo side panel
document.getElementById("openEchoBtn").addEventListener("click", async () => {
  const win = await chrome.windows.getCurrent();
  await chrome.sidePanel.open({ windowId: win.id });
  window.close();
});

render();
