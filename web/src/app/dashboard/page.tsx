import { Card } from "@/components/ui/card";
import {
  Footprints,
  Moon,
  Layers,
  Palette,
  Sparkles,
  TrendingUp,
  Clock,
  Zap,
  MapPin,
  Heart,
  ArrowUpRight,
  Activity,
  Monitor,
} from "lucide-react";

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 6) return "夜深了";
  if (hour < 12) return "早上好";
  if (hour < 14) return "中午好";
  if (hour < 18) return "下午好";
  if (hour < 22) return "晚上好";
  return "夜深了";
}

const statCards = [
  {
    label: "活动时间",
    value: "--",
    sub: "运动 · 步行",
    icon: Zap,
    tintClass: "from-orange-500/10 to-orange-400/5 ring-orange-500/10",
    iconColor: "text-orange-500",
  },
  {
    label: "睡眠",
    value: "--",
    sub: "昨晚",
    icon: Moon,
    tintClass: "from-indigo-500/10 to-indigo-400/5 ring-indigo-500/10",
    iconColor: "text-indigo-500",
  },
  {
    label: "屏幕时间",
    value: "--",
    sub: "今日总计",
    icon: Layers,
    tintClass: "from-violet-500/10 to-violet-400/5 ring-violet-500/10",
    iconColor: "text-violet-500",
  },
  {
    label: "心情",
    value: "😊",
    sub: "开心 · 2 条记录",
    icon: Palette,
    tintClass: "from-rose-500/10 to-rose-400/5 ring-rose-500/10",
    iconColor: "text-rose-500",
  },
];

const recentActivities = [
  { time: "09:30", label: "到达 公司", icon: MapPin, color: "text-blue-500" },
  { time: "10:15", label: "步行 12 分钟", icon: Footprints, color: "text-green-500" },
  { time: "11:00", label: "屏幕时间 · 效率工具 45m", icon: Monitor, color: "text-purple-500" },
  { time: "12:30", label: "记录心情 · 开心", icon: Heart, color: "text-rose-500" },
];

const weeklyData = [
  { day: "一", value: 65 },
  { day: "二", value: 80 },
  { day: "三", value: 45 },
  { day: "四", value: 90 },
  { day: "五", value: 70 },
  { day: "六", value: 30 },
  { day: "日", value: 55 },
];

export default function DashboardPage() {
  const greeting = getGreeting();
  const now = new Date();
  const dateStr = now.toLocaleDateString("zh-CN", {
    month: "long",
    day: "numeric",
    weekday: "long",
  });

  return (
    <div className="min-h-screen">
      {/* Hero Section */}
      <div className="px-10 pt-12 pb-8">
        <div className="flex items-center gap-3 mb-2">
          <div className="h-1 w-8 rounded-full bg-gradient-to-r from-[#D4864A] to-[#E8A06A]" />
          <h1 className="text-[32px] font-semibold tracking-tight text-foreground/90">
            {greeting}，Looan
          </h1>
        </div>
        <p className="text-[15px] text-muted-foreground ml-11">{dateStr}</p>
      </div>

      <div className="px-10 pb-10 space-y-6">
        {/* Stat Cards */}
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {statCards.map((card) => (
            <Card
              key={card.label}
              className="group relative overflow-hidden border-0 bg-white p-5 shadow-[0_1px_3px_rgba(0,0,0,0.04),0_1px_2px_rgba(0,0,0,0.02)] hover:shadow-[0_4px_12px_rgba(0,0,0,0.06)] transition-all duration-300"
            >
              <div className="flex items-start justify-between">
                <div className="space-y-3">
                  <p className="text-[13px] font-medium text-muted-foreground">{card.label}</p>
                  <p className="text-[28px] font-bold tracking-tight text-foreground/90">{card.value}</p>
                  <p className="text-[12px] text-muted-foreground/70">{card.sub}</p>
                </div>
                <div className={`rounded-xl p-2.5 bg-gradient-to-br ${card.tintClass} ring-1`}>
                  <card.icon className={`h-[18px] w-[18px] ${card.iconColor}`} strokeWidth={1.8} />
                </div>
              </div>
            </Card>
          ))}
        </div>

        {/* Main Grid */}
        <div className="grid gap-6 xl:grid-cols-3">
          {/* Timeline */}
          <Card className="xl:col-span-2 border-0 bg-white p-6 shadow-[0_1px_3px_rgba(0,0,0,0.04),0_1px_2px_rgba(0,0,0,0.02)]">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-2.5">
                <Activity className="h-[15px] w-[15px] text-muted-foreground" />
                <h2 className="text-[15px] font-semibold text-foreground/90">今日时间线</h2>
              </div>
              <div className="flex items-center gap-1.5 text-[12px] text-muted-foreground">
                <div className="h-1.5 w-1.5 rounded-full bg-green-400 animate-pulse" />
                实时
              </div>
            </div>

            {/* Activity Feed */}
            <div className="space-y-0">
              {recentActivities.map((activity, i) => (
                <div key={i} className="flex items-center gap-4 py-3 border-b border-border/40 last:border-0">
                  <span className="text-[13px] font-mono text-muted-foreground w-12">{activity.time}</span>
                  <div className="relative">
                    <div className={`h-2 w-2 rounded-full ${activity.color.replace('text-', 'bg-')}`} />
                    {i < recentActivities.length - 1 && (
                      <div className="absolute top-3 left-[3px] h-8 w-px bg-border/60" />
                    )}
                  </div>
                  <div className="flex-1">
                    <p className="text-[13px] text-foreground/80">{activity.label}</p>
                  </div>
                </div>
              ))}
            </div>

            {/* Empty state when no data */}
            <div className="mt-4 rounded-xl border border-dashed border-border/50 p-6 text-center">
              <p className="text-[13px] text-muted-foreground">
                连接数据源后，更多活动会自动出现在这里
              </p>
            </div>
          </Card>

          {/* Right Column */}
          <div className="space-y-6">
            {/* Echo AI */}
            <Card className="border-0 bg-white p-5 shadow-[0_1px_3px_rgba(0,0,0,0.04),0_1px_2px_rgba(0,0,0,0.02)]">
              <div className="flex items-center gap-2 mb-4">
                <Sparkles className="h-[15px] w-[15px] text-[#e8734a]" />
                <h2 className="text-[15px] font-semibold text-foreground/90">Echo</h2>
              </div>
              <div className="rounded-xl bg-[var(--background)] p-4 mb-3">
                <p className="text-[13px] text-foreground/70 leading-relaxed">
                  「今天看起来很充实。下午记得休息一下眼睛 ☕」
                </p>
                <p className="mt-2 text-[11px] text-muted-foreground">Echo · 刚刚</p>
              </div>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="跟 Echo 说点什么..."
                  className="flex-1 rounded-xl border-0 bg-[var(--background)] px-3.5 py-2.5 text-[13px] outline-none placeholder:text-muted-foreground/50 focus:ring-1 focus:ring-[#e8734a]/30"
                />
                <button className="rounded-xl bg-gradient-to-r from-[#e8734a] to-[#f59e6c] px-3.5 py-2.5 text-[12px] font-medium text-white shadow-sm hover:shadow transition-shadow">
                  发送
                </button>
              </div>
            </Card>

            {/* Weekly Activity */}
            <Card className="border-0 bg-white p-5 shadow-[0_1px_3px_rgba(0,0,0,0.04),0_1px_2px_rgba(0,0,0,0.02)]">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <TrendingUp className="h-[15px] w-[15px] text-muted-foreground" />
                  <h2 className="text-[15px] font-semibold text-foreground/90">本周活跃度</h2>
                </div>
                <button className="text-[12px] text-muted-foreground hover:text-foreground flex items-center gap-0.5 transition-colors">
                  详情 <ArrowUpRight className="h-3 w-3" />
                </button>
              </div>
              {/* Mini bar chart */}
              <div className="flex items-end justify-between gap-2 h-24">
                {weeklyData.map((d) => (
                  <div key={d.day} className="flex flex-col items-center gap-1.5 flex-1">
                    <div
                      className="w-full rounded-md bg-gradient-to-t from-[#e8734a]/80 to-[#f59e6c]/60 transition-all duration-500"
                      style={{ height: `${d.value}%` }}
                    />
                    <span className="text-[11px] text-muted-foreground">{d.day}</span>
                  </div>
                ))}
              </div>
            </Card>

            {/* Life Pulse */}
            <Card className="border-0 bg-white p-5 shadow-[0_1px_3px_rgba(0,0,0,0.04),0_1px_2px_rgba(0,0,0,0.02)]">
              <div className="flex items-center gap-2.5 mb-3">
                <div className="rounded-lg p-1.5 bg-emerald-500/8">
                  <Activity className="h-4 w-4 text-emerald-500" strokeWidth={1.8} />
                </div>
                <h2 className="text-[15px] font-semibold text-foreground/90">生活脉搏</h2>
              </div>
              <p className="text-[13px] leading-relaxed text-muted-foreground">
                连接你的手机和电脑后，ToDay 会自动分析你的生活节奏，给出个性化的洞察。
              </p>
            </Card>
          </div>
        </div>

        {/* Quick Actions — Claude-style buttons */}
        <Card className="border-0 bg-white p-5 shadow-[0_1px_3px_rgba(0,0,0,0.04),0_1px_2px_rgba(0,0,0,0.02)]">
          <p className="text-[13px] text-muted-foreground mb-3">快速操作</p>
          <div className="flex flex-wrap gap-2">
            {[
              { icon: Heart, label: "记录心情" },
              { icon: Clock, label: "补充时段" },
              { icon: Monitor, label: "查看屏幕时间" },
              { icon: Sparkles, label: "跟 Echo 聊天" },
              { icon: TrendingUp, label: "周报分析" },
            ].map((action) => (
              <button
                key={action.label}
                className="flex items-center gap-2 rounded-full border border-border/60 px-4 py-2 text-[13px] text-foreground/70 hover:bg-accent hover:text-foreground transition-all duration-150 hover:shadow-sm"
              >
                <action.icon className="h-3.5 w-3.5" />
                {action.label}
              </button>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}
