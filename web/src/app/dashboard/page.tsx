import { Card } from "@/components/ui/card";
import {
  Footprints,
  Moon,
  Monitor,
  Sparkles,
  TrendingUp,
  Clock,
} from "lucide-react";

const statCards = [
  {
    label: "今日步数",
    value: "--",
    icon: Footprints,
    color: "text-green-500",
    bg: "bg-green-500/10",
  },
  {
    label: "睡眠",
    value: "--",
    icon: Moon,
    color: "text-indigo-500",
    bg: "bg-indigo-500/10",
  },
  {
    label: "屏幕时间",
    value: "--",
    icon: Monitor,
    color: "text-purple-500",
    bg: "bg-purple-500/10",
  },
  {
    label: "活动事件",
    value: "--",
    icon: TrendingUp,
    color: "text-orange-500",
    bg: "bg-orange-500/10",
  },
];

export default function DashboardPage() {
  const now = new Date();
  const dateStr = now.toLocaleDateString("zh-CN", {
    year: "numeric",
    month: "long",
    day: "numeric",
    weekday: "long",
  });

  return (
    <div className="p-8">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold tracking-tight">概览</h1>
        <p className="mt-1 text-muted-foreground">{dateStr}</p>
      </div>

      {/* Stat Cards */}
      <div className="mb-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {statCards.map((card) => (
          <Card key={card.label} className="p-5">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">{card.label}</p>
                <p className="mt-1 text-2xl font-bold">{card.value}</p>
              </div>
              <div className={`rounded-lg p-2.5 ${card.bg}`}>
                <card.icon className={`h-5 w-5 ${card.color}`} />
              </div>
            </div>
          </Card>
        ))}
      </div>

      {/* Main Content Grid */}
      <div className="grid gap-6 lg:grid-cols-3">
        {/* Timeline Preview */}
        <Card className="col-span-2 p-6">
          <div className="mb-4 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Clock className="h-4 w-4 text-muted-foreground" />
              <h2 className="font-semibold">今日时间线</h2>
            </div>
            <span className="text-xs text-muted-foreground">实时</span>
          </div>
          <div className="flex h-64 items-center justify-center rounded-lg border border-dashed border-border/60">
            <div className="text-center">
              <Clock className="mx-auto mb-3 h-10 w-10 text-muted-foreground/40" />
              <p className="text-sm text-muted-foreground">
                连接数据源后，你的一天会在这里展开
              </p>
              <p className="mt-1 text-xs text-muted-foreground/60">
                手机数据 · 电脑使用 · 活动记录
              </p>
            </div>
          </div>
        </Card>

        {/* Echo AI */}
        <Card className="p-6">
          <div className="mb-4 flex items-center gap-2">
            <Sparkles className="h-4 w-4 text-orange-500" />
            <h2 className="font-semibold">Echo</h2>
          </div>
          <div className="flex h-64 flex-col">
            <div className="flex-1 rounded-lg border border-dashed border-border/60 p-4">
              <p className="text-sm text-muted-foreground">
                你的 AI 生活伙伴，随时可以聊聊今天的感受。
              </p>
            </div>
            <div className="mt-3 flex gap-2">
              <input
                type="text"
                placeholder="跟 Echo 说点什么..."
                className="flex-1 rounded-lg border border-input bg-background px-3 py-2 text-sm"
                disabled
              />
              <button
                className="rounded-lg bg-gradient-to-r from-orange-400 to-orange-500 px-3 py-2 text-sm font-medium text-white"
                disabled
              >
                发送
              </button>
            </div>
          </div>
        </Card>
      </div>

      {/* Life Pulse */}
      <Card className="mt-6 p-6">
        <div className="mb-3 flex items-center gap-2">
          <span className="text-lg">🌿</span>
          <h2 className="font-semibold">生活脉搏</h2>
        </div>
        <p className="text-sm leading-relaxed text-muted-foreground">
          连接你的手机和电脑后，ToDay 会自动分析你的生活节奏，给出个性化的洞察和建议。
        </p>
      </Card>
    </div>
  );
}
