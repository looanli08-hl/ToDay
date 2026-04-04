// Category rules — domain patterns mapped to categories
const CATEGORY_RULES = [
  // Social
  { pattern: /twitter\.com|x\.com/, category: "社交", label: "Twitter" },
  { pattern: /facebook\.com/, category: "社交", label: "Facebook" },
  { pattern: /instagram\.com/, category: "社交", label: "Instagram" },
  { pattern: /weibo\.com/, category: "社交", label: "微博" },
  { pattern: /reddit\.com/, category: "社交", label: "Reddit" },
  { pattern: /linkedin\.com/, category: "社交", label: "LinkedIn" },
  { pattern: /jike\.city|okjike\.com/, category: "社交", label: "即刻" },

  // Video & Entertainment
  { pattern: /youtube\.com/, category: "娱乐", label: "YouTube" },
  { pattern: /bilibili\.com/, category: "娱乐", label: "Bilibili" },
  { pattern: /netflix\.com/, category: "娱乐", label: "Netflix" },
  { pattern: /douyin\.com|tiktok\.com/, category: "娱乐", label: "抖音/TikTok" },
  { pattern: /twitch\.tv/, category: "娱乐", label: "Twitch" },

  // Productivity
  { pattern: /notion\.so/, category: "效率", label: "Notion" },
  { pattern: /github\.com/, category: "效率", label: "GitHub" },
  { pattern: /gitlab\.com/, category: "效率", label: "GitLab" },
  { pattern: /docs\.google\.com/, category: "效率", label: "Google Docs" },
  { pattern: /figma\.com/, category: "效率", label: "Figma" },
  { pattern: /linear\.app/, category: "效率", label: "Linear" },
  { pattern: /stackoverflow\.com/, category: "效率", label: "Stack Overflow" },
  { pattern: /vercel\.com/, category: "效率", label: "Vercel" },
  { pattern: /supabase\.com/, category: "效率", label: "Supabase" },

  // Communication
  { pattern: /mail\.google\.com|outlook\./, category: "通讯", label: "邮件" },
  { pattern: /slack\.com/, category: "通讯", label: "Slack" },
  { pattern: /discord\.com/, category: "通讯", label: "Discord" },
  { pattern: /teams\.microsoft\.com/, category: "通讯", label: "Teams" },
  { pattern: /web\.telegram\.org/, category: "通讯", label: "Telegram" },

  // Shopping
  { pattern: /amazon\./, category: "购物", label: "Amazon" },
  { pattern: /taobao\.com|tmall\.com/, category: "购物", label: "淘宝/天猫" },
  { pattern: /jd\.com/, category: "购物", label: "京东" },

  // Learning
  { pattern: /coursera\.org/, category: "学习", label: "Coursera" },
  { pattern: /udemy\.com/, category: "学习", label: "Udemy" },
  { pattern: /zhihu\.com/, category: "学习", label: "知乎" },
  { pattern: /medium\.com/, category: "学习", label: "Medium" },
  { pattern: /dev\.to/, category: "学习", label: "DEV" },
  { pattern: /wikipedia\.org/, category: "学习", label: "Wikipedia" },

  // Search
  { pattern: /google\.com\/search|bing\.com|baidu\.com/, category: "搜索", label: "搜索引擎" },

  // AI Tools
  { pattern: /claude\.ai|anthropic\.com/, category: "AI工具", label: "Claude" },
  { pattern: /chat\.openai\.com|chatgpt\.com/, category: "AI工具", label: "ChatGPT" },
  { pattern: /deepseek\.com/, category: "AI工具", label: "DeepSeek" },
];

export function categorize(url) {
  try {
    const hostname = new URL(url).hostname;
    for (const rule of CATEGORY_RULES) {
      if (rule.pattern.test(hostname)) {
        return { category: rule.category, label: rule.label };
      }
    }
    // Default: use domain as label
    const domain = hostname.replace(/^www\./, "");
    return { category: "其他", label: domain };
  } catch {
    return { category: "其他", label: "未知" };
  }
}
