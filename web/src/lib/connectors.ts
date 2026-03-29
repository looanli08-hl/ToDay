export interface Connector {
  id: string;
  name: string;
  description: string;
  icon: string; // emoji
  category: "health" | "productivity" | "social" | "finance" | "entertainment";
  status: "available" | "coming_soon" | "community";
  dataTypes: string[];
  author: string;
}

export const connectors: Connector[] = [
  {
    id: "apple-health",
    name: "Apple Health",
    description: "同步 iPhone 的步数、心率、睡眠、运动数据",
    icon: "❤️",
    category: "health",
    status: "available",
    dataTypes: ["steps", "heartRate", "sleep", "workout"],
    author: "ToDay 官方",
  },
  {
    id: "fitbit",
    name: "Fitbit",
    description: "连接 Fitbit 手环，同步运动和健康数据",
    icon: "⌚",
    category: "health",
    status: "coming_soon",
    dataTypes: ["steps", "heartRate", "sleep"],
    author: "ToDay 官方",
  },
  {
    id: "notion",
    name: "Notion",
    description: "追踪 Notion 使用时间，记录知识工作",
    icon: "📝",
    category: "productivity",
    status: "coming_soon",
    dataTypes: ["screenTime", "productivity"],
    author: "ToDay 官方",
  },
  {
    id: "spotify",
    name: "Spotify",
    description: "记录音乐收听历史，分析听歌偏好",
    icon: "🎵",
    category: "entertainment",
    status: "coming_soon",
    dataTypes: ["music", "listening"],
    author: "ToDay 官方",
  },
  {
    id: "wechat-pay",
    name: "微信支付",
    description: "导入消费记录，追踪日常开支",
    icon: "💰",
    category: "finance",
    status: "coming_soon",
    dataTypes: ["spending"],
    author: "社区",
  },
  {
    id: "xiaomi-band",
    name: "小米手环",
    description: "同步小米手环的运动和睡眠数据",
    icon: "📱",
    category: "health",
    status: "community",
    dataTypes: ["steps", "sleep", "heartRate"],
    author: "社区",
  },
  {
    id: "bilibili",
    name: "Bilibili",
    description: "记录 B 站观看时间和历史",
    icon: "📺",
    category: "entertainment",
    status: "community",
    dataTypes: ["screenTime", "entertainment"],
    author: "社区",
  },
  {
    id: "toggl",
    name: "Toggl Track",
    description: "同步时间追踪数据，了解工作时间分配",
    icon: "⏱️",
    category: "productivity",
    status: "community",
    dataTypes: ["timeTracking", "productivity"],
    author: "社区",
  },
];

export const categories = [
  { id: "all", label: "全部" },
  { id: "health", label: "健康" },
  { id: "productivity", label: "效率" },
  { id: "entertainment", label: "娱乐" },
  { id: "finance", label: "财务" },
  { id: "social", label: "社交" },
] as const;
