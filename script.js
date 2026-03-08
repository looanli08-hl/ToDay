const storageKey = "panji-pro-records";

const defaultRecords = [
  {
    id: 1,
    date: "2026-03-08",
    mode: "做T",
    symbol: "300750",
    name: "宁德时代",
    session: "早盘",
    plan: "冲高减仓，回踩 5 日线接回，吃到主升段内日内差价。",
    pnl: 3280,
    discipline: 93,
    note: "减仓执行果断，接回早了两分钟，仍在计划内。"
  },
  {
    id: 2,
    date: "2026-03-07",
    mode: "格局",
    symbol: "603986",
    name: "兆易创新",
    session: "波段",
    plan: "趋势未坏，成交量健康，财报前维持格局。",
    pnl: 5820,
    discipline: 88,
    note: "抗住盘中回撤，最终验证逻辑正确。"
  },
  {
    id: 3,
    date: "2026-03-06",
    mode: "做T",
    symbol: "002594",
    name: "比亚迪",
    session: "午后",
    plan: "午后资金回流时做反包 T，博弈情绪修复。",
    pnl: -640,
    discipline: 74,
    note: "追高偏急，下次需等分时放量确认。"
  },
  {
    id: 4,
    date: "2026-03-05",
    mode: "格局",
    symbol: "601127",
    name: "赛力斯",
    session: "波段",
    plan: "高位震荡但主线强，继续格局，防守位明确。",
    pnl: 4760,
    discipline: 91,
    note: "格局有效，执行完整，没有被震出去。"
  },
  {
    id: 5,
    date: "2026-03-04",
    mode: "做T",
    symbol: "688111",
    name: "金山办公",
    session: "尾盘",
    plan: "尾盘回流尝试低吸，次日看兑现。",
    pnl: 1210,
    discipline: 86,
    note: "低吸位置合格，隔夜预案清晰。"
  },
  {
    id: 6,
    date: "2026-03-03",
    mode: "格局",
    symbol: "300308",
    name: "中际旭创",
    session: "波段",
    plan: "业绩驱动延续，趋势没坏，继续持有。",
    pnl: 3630,
    discipline: 90,
    note: "按照计划拿住，收益来自纪律。"
  }
];

const navItems = [...document.querySelectorAll(".nav-item")];
const screens = [...document.querySelectorAll(".screen")];
const quickNavs = [...document.querySelectorAll(".quick-nav")];
const segments = [...document.querySelectorAll(".segment")];
const templatePills = [...document.querySelectorAll(".template-pill")];
const recordForm = document.getElementById("recordForm");
const toast = document.getElementById("toast");

const refs = {
  todayResult: document.getElementById("todayResult"),
  tradeRate: document.getElementById("tradeRate"),
  disciplineScore: document.getElementById("disciplineScore"),
  swingPnl: document.getElementById("swingPnl"),
  holdPnl: document.getElementById("holdPnl"),
  bestSession: document.getElementById("bestSession"),
  streakCount: document.getElementById("streakCount"),
  weeklyResult: document.getElementById("weeklyResult"),
  avgTrade: document.getElementById("avgTrade"),
  recentRecords: document.getElementById("recentRecords"),
  reviewTradeCount: document.getElementById("reviewTradeCount"),
  reviewWinRate: document.getElementById("reviewWinRate"),
  reviewDiscipline: document.getElementById("reviewDiscipline"),
  heatMap: document.getElementById("heatMap"),
  insightList: document.getElementById("insightList"),
  chartLine: document.getElementById("chartLine"),
  chartArea: document.getElementById("chartArea"),
  chartDots: document.getElementById("chartDots"),
  chartLabels: document.getElementById("chartLabels")
};

const modeInput = document.getElementById("modeInput");
const planInput = document.getElementById("planInput");

let records = loadRecords();

function getTodayIso() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function loadRecords() {
  try {
    const raw = localStorage.getItem(storageKey);
    if (!raw) return [...defaultRecords];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) && parsed.length ? parsed : [...defaultRecords];
  } catch {
    return [...defaultRecords];
  }
}

function persistRecords() {
  localStorage.setItem(storageKey, JSON.stringify(records));
}

function activateScreen(target) {
  screens.forEach((screen) => {
    screen.classList.toggle("is-active", screen.dataset.screen === target);
  });

  navItems.forEach((item) => {
    item.classList.toggle("is-active", item.dataset.target === target);
  });
}

function setMode(mode) {
  modeInput.value = mode;
  segments.forEach((segment) => {
    segment.classList.toggle("is-selected", segment.dataset.mode === mode);
  });
}

function formatCurrency(value) {
  const prefix = value >= 0 ? "+" : "";
  return `${prefix}${Math.round(value).toLocaleString("zh-CN")}`;
}

function getStats() {
  const todayIso = getTodayIso();
  const total = records.length;
  const wins = records.filter((item) => item.pnl > 0);
  const avgDiscipline = total
    ? Math.round(records.reduce((sum, item) => sum + item.discipline, 0) / total)
    : 0;
  const tRecords = records.filter((item) => item.mode === "做T");
  const holdRecords = records.filter((item) => item.mode === "格局");
  const weekly = records.slice(0, 7).reduce((sum, item) => sum + item.pnl, 0);
  const today = records
    .filter((item) => item.date === todayIso)
    .reduce((sum, item) => sum + item.pnl, 0);
  const sessionTotals = records.reduce((acc, item) => {
    acc[item.session] = (acc[item.session] || 0) + item.pnl;
    return acc;
  }, {});
  const bestSession =
    Object.entries(sessionTotals).sort((a, b) => b[1] - a[1])[0]?.[0] || "早盘";

  let streak = 0;
  for (const item of records) {
    if (item.pnl > 0) {
      streak += 1;
    } else {
      break;
    }
  }

  return {
    total,
    winRate: total ? Math.round((wins.length / total) * 100) : 0,
    avgDiscipline,
    tPnl: tRecords.reduce((sum, item) => sum + item.pnl, 0),
    tCount: tRecords.length,
    holdPnl: holdRecords.reduce((sum, item) => sum + item.pnl, 0),
    holdCount: holdRecords.length,
    weekly,
    avgTrade: total ? Math.round(records.reduce((sum, item) => sum + item.pnl, 0) / total) : 0,
    today,
    bestSession,
    streak
  };
}

function renderOverview() {
  const stats = getStats();

  refs.todayResult.textContent = formatCurrency(stats.today);
  refs.todayResult.className = stats.today >= 0 ? "rise" : "fall";
  refs.tradeRate.textContent = `${stats.winRate}%`;
  refs.disciplineScore.textContent = stats.avgDiscipline;
  refs.swingPnl.textContent = formatCurrency(stats.tPnl);
  refs.holdPnl.textContent = formatCurrency(stats.holdPnl);
  refs.bestSession.textContent = stats.bestSession;
  refs.streakCount.textContent = `${stats.streak} 天`;
  refs.weeklyResult.textContent = formatCurrency(stats.weekly);
  refs.avgTrade.textContent = formatCurrency(stats.avgTrade);

  refs.recentRecords.innerHTML = records
    .slice(0, 4)
    .map((item) => {
      const resultClass = item.pnl >= 0 ? "rise" : "fall";
      return `
        <article class="record-item">
          <div class="record-top">
            <div>
              <strong>${item.name}</strong>
              <div class="record-code">
                <span>${item.symbol}</span>
                <span>${item.mode}</span>
                <span>${item.date}</span>
              </div>
            </div>
            <div class="record-result ${resultClass}">
              <small>${item.session}</small>
              <strong>${formatCurrency(item.pnl)}</strong>
            </div>
          </div>
          <div class="record-meta">
            <span>纪律 ${item.discipline}</span>
            <span>${item.mode === "做T" ? "日内差价" : "趋势格局"}</span>
            <span>${item.session}</span>
          </div>
          <div class="record-body">
            <strong>逻辑：</strong>${item.plan}<br />
            <strong>复盘：</strong>${item.note || "暂无备注"}
          </div>
        </article>
      `;
    })
    .join("");
}

function renderReview() {
  const stats = getStats();
  refs.reviewTradeCount.textContent = stats.total;
  refs.reviewWinRate.textContent = `${stats.winRate}%`;
  refs.reviewDiscipline.textContent = stats.avgDiscipline;

  const modeSummary = ["做T", "格局"].map((mode) => {
    const subset = records.filter((item) => item.mode === mode);
    const pnl = subset.reduce((sum, item) => sum + item.pnl, 0);
    const winRate = subset.length
      ? Math.round((subset.filter((item) => item.pnl > 0).length / subset.length) * 100)
      : 0;
    return { mode, pnl, winRate, count: subset.length };
  });

  refs.heatMap.innerHTML = modeSummary
    .map(
      (item) => `
        <article class="heat-item">
          <span class="eyebrow">${item.mode}</span>
          <strong class="${item.pnl >= 0 ? "rise" : "fall"}">${formatCurrency(item.pnl)}</strong>
          <p>样本 ${item.count} 笔 / 胜率 ${item.winRate}%</p>
        </article>
      `
    )
    .join("");

  const bestMode = modeSummary.sort((a, b) => b.pnl - a.pnl)[0];
  const worstDiscipline = [...records].sort((a, b) => a.discipline - b.discipline)[0];
  const bestSession = stats.bestSession;

  refs.insightList.innerHTML = [
    {
      title: "最强赚钱场景",
      body: `${bestMode.mode} 当前累计结果最高，建议把这类操作沉淀成付费模板或陪跑课程中的标准剧本。`
    },
    {
      title: "最佳出手时段",
      body: `${bestSession} 的累计收益领先，说明你的决策更适合在该时段执行，午后或尾盘应减少冲动操作。`
    },
    {
      title: "当前最明显短板",
      body: `${worstDiscipline.name} 这笔记录纪律分最低，说明问题不在逻辑，而在执行。会员版可以把此类问题做成纪律诊断服务。`
    }
  ]
    .map(
      (item) => `
        <article class="insight">
          <strong>${item.title}</strong>
          <p>${item.body}</p>
        </article>
      `
    )
    .join("");
}

function renderChart() {
  const chartData = [...records]
    .slice(0, 7)
    .reverse()
    .map((item) => ({ label: item.date.slice(5).replace("-", "/"), value: item.pnl }));

  const values = chartData.map((item) => item.value);
  const max = Math.max(...values, 0);
  const min = Math.min(...values, 0);
  const spread = max - min || 1;
  const width = 320;
  const height = 180;
  const stepX = width / (chartData.length - 1 || 1);

  const points = chartData.map((item, index) => {
    const x = index * stepX;
    const normalized = (item.value - min) / spread;
    const y = height - 22 - normalized * 118;
    return { x, y, label: item.label };
  });

  const line = points
    .map((point, index) => `${index === 0 ? "M" : "L"} ${point.x.toFixed(2)} ${point.y.toFixed(2)}`)
    .join(" ");
  const area = `${line} L ${points[points.length - 1]?.x ?? 0} ${height} L 0 ${height} Z`;

  refs.chartLine.setAttribute("d", line);
  refs.chartArea.setAttribute("d", area);
  refs.chartDots.innerHTML = points
    .map((point) => `<circle class="chart-dot" cx="${point.x}" cy="${point.y}" r="4.5"></circle>`)
    .join("");
  refs.chartLabels.innerHTML = chartData.map((item) => `<span>${item.label}</span>`).join("");
}

function renderAll() {
  renderOverview();
  renderReview();
  renderChart();
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.add("is-visible");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => {
    toast.classList.remove("is-visible");
  }, 1800);
}

navItems.forEach((item) => {
  item.addEventListener("click", () => activateScreen(item.dataset.target));
});

quickNavs.forEach((button) => {
  button.addEventListener("click", () => activateScreen(button.dataset.target));
});

segments.forEach((segment) => {
  segment.addEventListener("click", () => setMode(segment.dataset.mode));
});

templatePills.forEach((pill) => {
  pill.addEventListener("click", () => {
    planInput.value = pill.dataset.template;
  });
});

recordForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const formData = new FormData(recordForm);
  const pnl = Number(formData.get("pnl"));
  const discipline = Number(formData.get("discipline"));

  const newRecord = {
    id: Date.now(),
    date: getTodayIso(),
    mode: String(formData.get("mode")),
    symbol: String(formData.get("symbol")).trim(),
    name: String(formData.get("name")).trim(),
    session: String(formData.get("session")),
    plan: String(formData.get("plan")).trim(),
    pnl,
    discipline,
    note: String(formData.get("note")).trim()
  };

  records = [newRecord, ...records];
  persistRecords();
  renderAll();
  activateScreen("overview");
  recordForm.reset();
  setMode("做T");
  document.getElementById("disciplineInput").value = 90;
  showToast("记录已保存，收益与复盘统计已刷新");
});

setMode("做T");
renderAll();
