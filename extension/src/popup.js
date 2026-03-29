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
  const result = await chrome.storage.local.get(["sessions", "currentSession"]);
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

  // Render site list as time segments
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

// Open dashboard
document.getElementById("dashboardLink").addEventListener("click", () => {
  chrome.tabs.create({ url: "http://localhost:3001/dashboard" });
});

render();
