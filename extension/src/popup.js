function formatDuration(seconds) {
  if (seconds < 60) return `${seconds}s`;
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

async function render() {
  const todayKey = new Date().toISOString().split("T")[0];
  const result = await chrome.storage.local.get(["todayData"]);
  const todayData = result.todayData?.[todayKey] || {};

  const entries = Object.values(todayData)
    .filter(e => e.duration >= 30)
    .sort((a, b) => b.duration - a.duration);

  // Total time
  const totalSeconds = entries.reduce((sum, e) => sum + e.duration, 0);
  document.getElementById("totalTime").textContent = formatDuration(totalSeconds);

  // All sites — show every site with its duration
  const siteList = document.getElementById("siteList");
  if (entries.length === 0) {
    siteList.innerHTML = '<div class="empty-state"><p>继续浏览，数据会自动出现</p></div>';
  } else {
    siteList.innerHTML = entries.map(entry => `
      <div class="site-item">
        <span class="site-name">${entry.label || entry.domain}</span>
        <span class="site-time">${formatDuration(entry.duration)}</span>
      </div>
    `).join("");
  }
}

// Open dashboard
document.getElementById("dashboardLink").addEventListener("click", () => {
  chrome.tabs.create({ url: "http://localhost:3001/dashboard" });
});

// Render on popup open
render();
