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
  chartLabels: document.getElementById("chartLabels"),
  agentConfidence: document.getElementById("agentConfidence"),
  agentDirective: document.getElementById("agentDirective"),
  agentPrimaryRole: document.getElementById("agentPrimaryRole"),
  agentRoleHint: document.getElementById("agentRoleHint"),
  agentRiskLevel: document.getElementById("agentRiskLevel"),
  agentRiskHint: document.getElementById("agentRiskHint"),
  agentActionCount: document.getElementById("agentActionCount"),
  agentCardGrid: document.getElementById("agentCardGrid"),
  agentDecisionList: document.getElementById("agentDecisionList"),
  agentChecklist: document.getElementById("agentChecklist")
};

const modeInput = document.getElementById("modeInput");
const planInput = document.getElementById("planInput");
const agentRefreshButton = document.getElementById("agentRefreshButton");

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

function getAgentReport() {
  const stats = getStats();
  const latest = records[0];
  const recent = records.slice(0, 3);
  const lowDisciplineCount = records.filter((item) => item.discipline < 80).length;
  const lossCount = records.filter((item) => item.pnl < 0).length;
  const executionGap = records.filter((item) => item.pnl > 0 && item.discipline < 85).length;
  const recentLosses = recent.filter((item) => item.pnl < 0).length;
  const confidence = Math.max(
    56,
    Math.min(96, Math.round(stats.winRate * 0.45 + stats.avgDiscipline * 0.55 - recentLosses * 6))
  );

  let riskLevel = "低";
  let riskHint = "当前样本显示节奏稳定，可保持原有框架。";

  if (stats.avgDiscipline < 82 || recentLosses >= 2 || lossCount >= Math.ceil(records.length / 3)) {
    riskLevel = "高";
    riskHint = "连续性或执行质量偏弱，下一阶段应先收缩出手频率。";
  } else if (stats.avgDiscipline < 88 || recentLosses === 1 || lowDisciplineCount >= 2) {
    riskLevel = "中";
    riskHint = "收益还在，但执行波动已经出现，需要控节奏。";
  }

  const primaryRole =
    stats.avgDiscipline < 85 ? "执行官" : stats.winRate < 60 ? "风控官" : "策略官";
  const roleHintMap = {
    "执行官": "优先修复临盘动作变形，先把计划执行完整。",
    "风控官": "先处理回撤和错单，少做无把握出手。",
    "策略官": "优势场景已经浮现，下一步是把模式标准化。"
  };

  const bestMode =
    stats.tPnl >= stats.holdPnl
      ? { name: "做T", value: stats.tPnl, hint: "日内节奏更适合你当前风格。" }
      : { name: "格局", value: stats.holdPnl, hint: "趋势持有比频繁切换更有优势。" };

  const weakest =
    [...records].sort((a, b) => a.discipline - b.discipline)[0] || defaultRecords[0];

  const agents = [
    {
      title: "策略 Agent",
      badge: "Pattern",
      summary: `当前最优模式是${bestMode.name}，累计 ${formatCurrency(bestMode.value)}。${bestMode.hint}`
    },
    {
      title: "执行 Agent",
      badge: "Execution",
      summary:
        executionGap > 0
          ? `你有 ${executionGap} 笔“赚钱但不标准”的交易，说明收益覆盖了缺陷，问题还没真正解决。`
          : "当前赚钱交易和执行质量基本一致，可以开始把流程固化为模板。"
    },
    {
      title: "风控 Agent",
      badge: "Risk",
      summary:
        riskLevel === "高"
          ? "系统建议下一阶段缩仓、减少追高，并把单日错单次数控制在 1 次以内。"
          : `最佳出手时段在${stats.bestSession}，非优势时段要更严格过滤信号。`
    },
    {
      title: "教练 Agent",
      badge: "Coach",
      summary: `最近最该复盘的是 ${weakest.name}，纪律分 ${weakest.discipline}，要回看“计划和动作为什么脱节”。`
    }
  ];

  const decisions = [
    {
      title: "主攻优势场景",
      body: `未来 3 个交易日内，把 ${bestMode.name} 作为主模式，非优势模式只有在计划充分时才允许出手。`
    },
    {
      title: "限制非优势时段",
      body: `${stats.bestSession} 之外的交易要先过一遍计划检查，尤其避免情绪波动后的追单。`
    },
    {
      title: "复盘最低纪律样本",
      body: `${weakest.date} 的 ${weakest.name} 是当前最明显的偏差样本，先复盘这笔，比盲目多看行情更有效。`
    }
  ];

  const checklist = [
    {
      phase: "开盘前",
      text: `只保留 1 到 2 个主交易剧本，优先 ${bestMode.name}，并写出触发条件与取消条件。`
    },
    {
      phase: "盘中",
      text:
        riskLevel === "高"
          ? "若连续两次动作不在计划内，立即停止新增仓位，转为观察模式。"
          : `把主要注意力放在 ${stats.bestSession}，其余时段不主动追击。`
    },
    {
      phase: "收盘后",
      text: `重点复盘 ${latest.name} 和 ${weakest.name} 两笔，分别回答“为什么赚”和“为什么变形”。`
    }
  ];

  return {
    confidence,
    riskLevel,
    riskHint,
    primaryRole,
    roleHint: roleHintMap[primaryRole],
    directive:
      riskLevel === "高"
        ? "先降噪，再求收益"
        : bestMode.name === "做T"
          ? "把优势做T模板化"
          : "把趋势格局标准化",
    agents,
    decisions,
    checklist
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

function renderAgent() {
  const report = getAgentReport();

  refs.agentConfidence.textContent = `置信度 ${report.confidence}%`;
  refs.agentDirective.textContent = report.directive;
  refs.agentPrimaryRole.textContent = report.primaryRole;
  refs.agentRoleHint.textContent = report.roleHint;
  refs.agentRiskLevel.textContent = report.riskLevel;
  refs.agentRiskHint.textContent = report.riskHint;
  refs.agentActionCount.textContent = String(report.checklist.length);

  refs.agentCardGrid.innerHTML = report.agents
    .map(
      (item) => `
        <article class="agent-card">
          <span class="agent-badge">${item.badge}</span>
          <strong>${item.title}</strong>
          <p>${item.summary}</p>
        </article>
      `
    )
    .join("");

  refs.agentDecisionList.innerHTML = report.decisions
    .map(
      (item) => `
        <article class="insight">
          <strong>${item.title}</strong>
          <p>${item.body}</p>
        </article>
      `
    )
    .join("");

  refs.agentChecklist.innerHTML = report.checklist
    .map(
      (item, index) => `
        <article class="checklist-item">
          <span class="checklist-index">${index + 1}</span>
          <div>
            <span class="eyebrow">${item.phase}</span>
            <strong>${item.text}</strong>
          </div>
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
  renderAgent();
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

agentRefreshButton?.addEventListener("click", () => {
  renderAgent();
  showToast("Agent 已基于最新记录重新诊断");
});

setMode("做T");
renderAll();
