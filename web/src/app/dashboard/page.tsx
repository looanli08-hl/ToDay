"use client";

import { useState, useEffect } from "react";
import { Card } from "@/components/ui/card";
import {
  Moon,
  Layers,
  TrendingUp,
  Clock,
  Zap,
  Heart,
  ArrowUpRight,
  Activity,
  Monitor,
} from "lucide-react";
import { EchoSymbol } from "@/components/echo-symbol";
import { createClient } from "@/lib/supabase/client";

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
  { label: "活动时间", value: "--", sub: "运动 · 步行", icon: Zap },
  { label: "睡眠", value: "--", sub: "昨晚", icon: Moon },
  { label: "屏幕时间", value: "--", sub: "今日总计", icon: Layers },
  { label: "心情", value: "--", sub: "2 条记录", icon: Heart },
];

const recentActivities = [
  { time: "09:30", label: "到达 公司" },
  { time: "10:15", label: "步行 12 分钟" },
  { time: "11:00", label: "屏幕时间 · 效率工具 45m" },
  { time: "12:30", label: "记录心情 · 开心" },
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
  const [userName, setUserName] = useState("");
  const greeting = getGreeting();
  const now = new Date();
  const dateStr = now.toLocaleDateString("zh-CN", {
    month: "long",
    day: "numeric",
    weekday: "long",
  });

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) {
        setUserName(
          user.user_metadata?.display_name ||
            user.email?.split("@")[0] ||
            ""
        );
      }
    });
  }, []);

  return (
    <div className="min-h-screen">
      {/* Hero Section */}
      <div className="px-12 pt-12 pb-10">
        <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
          {greeting}{userName ? `，${userName}` : ""}
        </h1>
        <p className="text-base text-muted-foreground mt-2">{dateStr}</p>
      </div>

      <div className="px-12 pb-12 space-y-8">
        {/* Stat Cards */}
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {statCards.map((card) => (
            <Card
              key={card.label}
              className="border border-border/40 bg-card rounded-xl p-6 hover:shadow-sm transition-shadow duration-300"
            >
              <div className="flex items-start justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">{card.label}</p>
                  <p className="font-display text-2xl font-normal text-foreground mt-2">{card.value}</p>
                  <p className="text-xs text-muted-foreground/60 mt-1">{card.sub}</p>
                </div>
                <card.icon className="h-4 w-4 text-muted-foreground/25" strokeWidth={1.5} />
              </div>
            </Card>
          ))}
        </div>

        {/* Main Grid */}
        <div className="grid gap-6 xl:grid-cols-3">
          {/* Timeline */}
          <Card className="xl:col-span-2 border border-border/40 bg-card rounded-xl p-6">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-2.5">
                <Activity className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                <h2 className="font-display text-lg text-foreground">今日时间线</h2>
              </div>
              <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                <div className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                实时
              </div>
            </div>

            {/* Activity Feed */}
            <div className="space-y-0">
              {recentActivities.map((activity, i) => (
                <div key={i} className="flex items-center gap-4 py-3 border-b border-border/40 last:border-0">
                  <span className="text-sm font-mono text-muted-foreground w-12">{activity.time}</span>
                  <div className="relative">
                    <div className="h-2 w-2 rounded-full bg-muted-foreground/30" />
                    {i < recentActivities.length - 1 && (
                      <div className="absolute top-3 left-[3px] h-8 w-px bg-border/60" />
                    )}
                  </div>
                  <div className="flex-1">
                    <p className="text-sm text-foreground/80">{activity.label}</p>
                  </div>
                </div>
              ))}
            </div>

            {/* Empty state when no data */}
            <div className="mt-4 rounded-xl border border-dashed border-border/50 p-6 text-center">
              <p className="text-sm text-muted-foreground">
                连接数据源后，更多活动会自动出现在这里
              </p>
            </div>
          </Card>

          {/* Right Column */}
          <div className="space-y-6">
            {/* Echo AI */}
            <Card className="border border-border/40 bg-card rounded-xl p-6">
              <div className="flex items-center gap-2 mb-4">
                <EchoSymbol size={15} className="text-primary" />
                <h2 className="font-display text-lg text-foreground">Echo</h2>
              </div>
              <div className="rounded-xl bg-background p-4 mb-3">
                <p className="text-sm text-foreground/70 leading-relaxed">
                  「今天看起来很充实。下午记得休息一下眼睛」
                </p>
                <p className="mt-2 text-[11px] text-muted-foreground">Echo · 刚刚</p>
              </div>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="跟 Echo 说点什么..."
                  className="flex-1 rounded-lg border border-border bg-background px-4 py-2.5 text-sm placeholder:text-muted-foreground/50 outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40 transition-all"
                />
                <button className="bg-primary text-primary-foreground rounded-lg px-4 py-2 text-sm font-medium hover:opacity-90 transition-opacity">
                  发送
                </button>
              </div>
            </Card>

            {/* Weekly Activity */}
            <Card className="border border-border/40 bg-card rounded-xl p-6">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <TrendingUp className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                  <h2 className="font-display text-lg text-foreground">本周活跃度</h2>
                </div>
                <button className="text-xs text-muted-foreground hover:text-foreground flex items-center gap-0.5 transition-colors">
                  详情 <ArrowUpRight className="h-3 w-3" />
                </button>
              </div>
              {/* Mini bar chart */}
              <div className="flex items-end justify-between gap-2 h-24">
                {weeklyData.map((d) => (
                  <div key={d.day} className="flex flex-col items-center gap-1.5 flex-1">
                    <div
                      className="w-full rounded-lg bg-primary/70 transition-all duration-500"
                      style={{ height: `${d.value}%` }}
                    />
                    <span className="text-[11px] text-muted-foreground">{d.day}</span>
                  </div>
                ))}
              </div>
            </Card>

            {/* Life Pulse */}
            <Card className="border border-border/40 bg-card rounded-xl p-6">
              <div className="flex items-center gap-2 mb-3">
                <Activity className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                <h2 className="font-display text-lg text-foreground">生活脉搏</h2>
              </div>
              <p className="text-sm leading-relaxed text-muted-foreground">
                连接你的手机和电脑后，ToDay 会自动分析你的生活节奏，给出个性化的洞察。
              </p>
            </Card>
          </div>
        </div>

        {/* Quick Actions */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <p className="text-sm text-muted-foreground mb-3">快速操作</p>
          <div className="flex flex-wrap gap-2">
            {[
              { icon: Heart, label: "记录心情" },
              { icon: Clock, label: "补充时段" },
              { icon: Monitor, label: "查看屏幕时间" },
              { icon: Heart, label: "跟 Echo 聊天" },
              { icon: TrendingUp, label: "周报分析" },
            ].map((action) => (
              <button
                key={action.label}
                className="flex items-center gap-2 rounded-full border border-border/50 px-4 py-2 text-sm text-muted-foreground hover:text-foreground hover:border-border transition-colors"
              >
                <action.icon className="h-4 w-4" strokeWidth={1.5} />
                {action.label}
              </button>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}
