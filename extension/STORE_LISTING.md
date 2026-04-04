# Chrome Web Store Listing — ToDay 浏览器扩展

---

## Extension Name

**ToDay — 数字生活追踪**

---

## Short Description (132 chars max)

智能追踪你的数字生活 — 浏览时间分析、习惯洞察、与 Echo AI 联动

> Character count: 31 Chinese characters + punctuation ≈ 62 display chars. Well within limit.

---

## Detailed Description

**了解你真正花时间在哪里。**

ToDay 浏览器扩展是你数字生活的忠实记录者。它在后台静默工作，追踪你每天在各个网站上的真实时长 —— 不读页面内容，不干扰浏览，只记录你需要的数据。

**核心功能：**

• **每日浏览摘要** — 点击扩展图标，即刻查看今日已在各网站花费的时间，分社交、生产力、娱乐等类别清晰呈现。
• **自动分类** — 智能识别 200+ 常用网站，自动归类为学习、社交、娱乐、资讯等维度，无需手动配置。
• **仪表盘同步** — 配置同步令牌后，数据自动上传至你的 ToDay 仪表盘（daycho.com），生成跨设备的完整数字生活画像。
• **Echo AI 联动** — 浏览数据与 iOS 健康数据、日程等融合，Echo 为你提供个性化的习惯洞察和生活建议。
• **隐私优先** — 数据默认留在本地，仅你主动开启同步时才上传至你的私有账户。全程 HTTPS 加密。

**工作原理：**

1. 安装扩展后无需任何配置，即刻开始本地记录。
2. 点击工具栏图标查看今日统计。
3. （可选）在 daycho.com 注册账户，获取同步令牌，开启跨设备数据同步与 AI 洞察。

**隐私承诺：**

ToDay 从不读取页面正文内容，从不记录密码或表单数据，从不向第三方出售任何数据。完整隐私政策：https://daycho.com/privacy

**仪表盘：** https://daycho.com

---

## Category

**Productivity**

---

## Permission Justifications（供 Chrome 审核团队参考）

### Standard Permissions

| Permission | Justification |
|---|---|
| `tabs` | Monitor active tab changes to track which domain the user is currently browsing and for how long. Required to capture tab switch events and calculate per-domain session durations. |
| `activeTab` | Access the current tab's URL and title to categorize the domain (e.g., social, productivity, entertainment) and display a human-readable label in the popup. |
| `storage` | Store browsing sessions locally in `chrome.storage.local` and persist user preferences (sync token, API URL, category settings) in `chrome.storage.sync`. No external server is involved unless the user explicitly configures a sync token. |
| `alarms` | Schedule two recurring background tasks: (1) periodic data sync to the user's ToDay dashboard every 1 minute when sync is configured; (2) local cache cleanup every hour to prevent unbounded storage growth. |
| `idle` | Detect when the user is idle (no mouse/keyboard activity for 60+ seconds) to pause the active session timer. This ensures that time spent away from the computer is not incorrectly attributed to a website, keeping duration statistics accurate. |

### Host Permissions

| Host | Justification |
|---|---|
| `https://to-day-ten.vercel.app/*` | Legacy API endpoint for syncing browsing session data to the user's ToDay backend. Used only when the user has configured a sync token. |
| `https://daycho.com/*` | Primary production API endpoint for syncing browsing session data to the user's ToDay account at daycho.com. Used only when the user has configured a sync token. |

---

## Privacy Practices（供 Chrome 审核团队参考）

**Data collected:**
- Website domain (e.g., `github.com`)
- Page title (e.g., "GitHub — Where the world builds software")
- Time spent on domain per session (duration in seconds)

**Data NOT collected:**
- Page content, body text, or DOM data
- Passwords, form inputs, or any user-entered data
- Cookies or cross-site tracking identifiers
- Browsing activity in Incognito mode
- Geolocation or IP address

**Data handling:**
- All data is stored locally by default (`chrome.storage.local`)
- Cloud sync only occurs when the user explicitly provides a sync token obtained from their own ToDay account at daycho.com
- All network requests use HTTPS (TLS encrypted in transit)
- User can delete all cloud data at any time from dashboard settings
- User can uninstall the extension to wipe all local data immediately
- Data is never sold, shared, or monetized

**Data retention:**
- Local data: retained until extension is uninstalled or user clears it
- Cloud data: retained until user deletes it from account settings

---

## Screenshots Checklist (1280×800 or 640×400)

- [ ] Popup showing today's browsing summary with category breakdown
- [ ] Dashboard page at daycho.com with weekly trend charts
- [ ] Settings screen showing sync token configuration
- [ ] Echo AI insight card generated from browsing data
- [ ] Before/after comparison (raw time → categorized insight)

---

## Support URL

https://daycho.com

## Privacy Policy URL

https://daycho.com/privacy

---

*Last updated: 2026-04-01*
