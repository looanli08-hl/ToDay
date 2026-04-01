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
  Smartphone,
  Globe,
} from "lucide-react";
import { EchoSymbol } from "@/components/echo-symbol";
import { createClient } from "@/lib/supabase/client";
import Link from "next/link";

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 6) return "夜深了";
  if (hour < 12) return "早上好";
  if (hour < 14) return "中午好";
  if (hour < 18) return "下午好";
  if (hour < 22) return "晚上好";
  return "夜深了";
}

function formatMinutes(minutes: number): string {
  if (minutes === 0) return "--";
  if (minutes < 60) return `${minutes} 分钟`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m > 0 ? `${h}h ${m}m` : `${h} 小时`;
}

interface DashboardStats {
  steps: number;
  sleep_hours: number;
  screen_time_minutes: number;
  mood_latest: { emoji: string; name: string } | null;
  mood_count: number;
}

interface TimelineEvent {
  time: string;
  type: string;
  label: string;
}

interface DashboardData {
  stats: DashboardStats;
  timeline: TimelineEvent[];
  has_data: boolean;
}

export default function DashboardPage() {
  const [userName, setUserName] = useState("");
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [echoMessage, setEchoMessage] = useState("");
  const [echoLoading, setEchoLoading] = useState(true);
  const greeting = getGreeting();
  const now = new Date();
  const dateStr = now.toLocaleDateString("zh-CN", {
    month: "long",
    day: "numeric",
    weekday: "long",
  });

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data: { user } }) => {
      if (user) {
        setUserName(
          user.user_metadata?.display_name ||
            user.email?.split("@")[0] ||
            ""
        );

        // Fetch sync token for API auth
        const { data: profile } = await supabase
          .from("profiles")
          .select("sync_token")
          .eq("id", user.id)
          .single() as { data: { sync_token: string } | null };

        if (profile?.sync_token) {
          try {
            const res = await fetch(`/api/dashboard?token=${profile.sync_token}`);
            const json = await res.json();
            setData(json);

            // Fetch Echo dynamic insight
            try {
              const echoRes = await fetch("/api/echo/insight", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                  stats: json.stats,
                  timeline_count: json.timeline?.length || 0,
                  has_data: json.has_data,
                  hour: new Date().getHours(),
                  user_name: user.user_metadata?.display_name || "",
                }),
              });
              const echoJson = await echoRes.json();
              setEchoMessage(echoJson.message);
            } catch {
              setEchoMessage("在这里陪着你。");
            }
            setEchoLoading(false);
          } catch {
            setData({ stats: { steps: 0, sleep_hours: 0, screen_time_minutes: 0, mood_latest: null, mood_count: 0 }, timeline: [], has_data: false });
            setEchoLoading(false);
          }
        }
      }
      setLoading(false);
    });
  }, []);

  const stats = data?.stats;

  const statCards = [
    {
      label: "活动时间",
      value: stats?.steps ? `${stats.steps.toLocaleString()} 步` : "--",
      sub: "运动 · 步行",
      icon: Zap,
    },
    {
      label: "睡眠",
      value: stats?.sleep_hours ? `${stats.sleep_hours} 小时` : "--",
      sub: "昨晚",
      icon: Moon,
    },
    {
      label: "屏幕时间",
      value: stats?.screen_time_minutes ? formatMinutes(stats.screen_time_minutes) : "--",
      sub: "今日总计",
      icon: Layers,
    },
    {
      label: "心情",
      value: stats?.mood_latest ? stats.mood_latest.emoji : "--",
      sub: stats?.mood_count ? `${stats.mood_count} 条记录` : "暂无记录",
      icon: Heart,
    },
  ];

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
                  <p className={`font-display text-2xl font-normal mt-2 ${card.value === "--" ? "text-muted-foreground/30" : "text-foreground"}`}>
                    {loading ? (
                      <span className="inline-block w-16 h-7 bg-muted-foreground/10 rounded animate-pulse" />
                    ) : (
                      card.value
                    )}
                  </p>
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

            {loading ? (
              <div className="space-y-3">
                {[1, 2, 3].map((i) => (
                  <div key={i} className="flex items-center gap-4 py-3">
                    <span className="w-12 h-4 bg-muted-foreground/10 rounded animate-pulse" />
                    <div className="h-2 w-2 rounded-full bg-muted-foreground/10" />
                    <span className="flex-1 h-4 bg-muted-foreground/10 rounded animate-pulse" />
                  </div>
                ))}
              </div>
            ) : data?.timeline && data.timeline.length > 0 ? (
              <div className="space-y-0">
                {data.timeline.map((event, i) => (
                  <div key={i} className="flex items-center gap-4 py-3 border-b border-border/40 last:border-0">
                    <span className="text-sm font-mono text-muted-foreground w-12">{event.time}</span>
                    <div className="relative">
                      <div className={`h-2 w-2 rounded-full ${
                        event.type === "mood" ? "bg-pink-400" :
                        event.type === "sleep" ? "bg-indigo-400" :
                        event.type === "screen" ? "bg-amber-400" :
                        "bg-emerald-400"
                      }`} />
                      {i < data.timeline.length - 1 && (
                        <div className="absolute top-3 left-[3px] h-8 w-px bg-border/60" />
                      )}
                    </div>
                    <div className="flex-1">
                      <p className="text-sm text-foreground/80">{event.label}</p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="rounded-xl border border-dashed border-border/50 p-8 text-center">
                <p className="text-sm text-muted-foreground mb-4">
                  连接你的设备，开始记录生活
                </p>
                <div className="flex justify-center gap-3">
                  <Link
                    href="/dashboard/connectors"
                    className="flex items-center gap-2 rounded-full border border-border/50 px-4 py-2 text-sm text-muted-foreground hover:text-foreground hover:border-border transition-colors"
                  >
                    <Globe className="h-4 w-4" strokeWidth={1.5} />
                    安装浏览器扩展
                  </Link>
                  <Link
                    href="/dashboard/settings"
                    className="flex items-center gap-2 rounded-full border border-border/50 px-4 py-2 text-sm text-muted-foreground hover:text-foreground hover:border-border transition-colors"
                  >
                    <Smartphone className="h-4 w-4" strokeWidth={1.5} />
                    连接手机 App
                  </Link>
                </div>
              </div>
            )}
          </Card>

          {/* Right Column */}
          <div className="space-y-6">
            {/* Echo AI */}
            <Link href="/dashboard/echo" className="block">
              <Card className="border border-border/40 bg-card rounded-xl p-6 hover:shadow-sm transition-shadow duration-300 cursor-pointer">
                <div className="flex items-center gap-2 mb-4">
                  <EchoSymbol size={15} className="text-primary" />
                  <h2 className="font-display text-lg text-foreground">Echo</h2>
                </div>
                <div className="rounded-xl bg-background p-4 mb-3">
                  {echoLoading ? (
                    <div className="flex items-center gap-2">
                      <div className="h-2 w-2 rounded-full bg-primary/40 animate-pulse" />
                      <div className="h-2 w-2 rounded-full bg-primary/30 animate-pulse" style={{ animationDelay: "0.3s" }} />
                      <div className="h-2 w-2 rounded-full bg-primary/20 animate-pulse" style={{ animationDelay: "0.6s" }} />
                    </div>
                  ) : (
                    <>
                      <p className="text-sm text-foreground/70 leading-relaxed">
                        {echoMessage.startsWith("「") ? echoMessage : `「${echoMessage}」`}
                      </p>
                      <p className="mt-2 text-[11px] text-muted-foreground">Echo · 刚刚</p>
                    </>
                  )}
                </div>
                <p className="text-xs text-muted-foreground text-center">点击和 Echo 聊天 →</p>
              </Card>
            </Link>

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
              <div className="flex items-end justify-between gap-2 h-24">
                {["一", "二", "三", "四", "五", "六", "日"].map((d) => (
                  <div key={d} className="flex flex-col items-center gap-1.5 flex-1">
                    <div
                      className="w-full rounded-lg bg-muted-foreground/10 transition-all duration-500"
                      style={{ height: "20%" }}
                    />
                    <span className="text-[11px] text-muted-foreground">{d}</span>
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
              { icon: Monitor, label: "查看屏幕时间", href: "/dashboard/screen-time" },
              { icon: Heart, label: "跟 Echo 聊天", href: "/dashboard/echo" },
              { icon: TrendingUp, label: "周报分析" },
            ].map((action) => (
              action.href ? (
                <Link
                  key={action.label}
                  href={action.href}
                  className="flex items-center gap-2 rounded-full border border-border/50 px-4 py-2 text-sm text-muted-foreground hover:text-foreground hover:border-border transition-colors"
                >
                  <action.icon className="h-4 w-4" strokeWidth={1.5} />
                  {action.label}
                </Link>
              ) : (
                <button
                  key={action.label}
                  className="flex items-center gap-2 rounded-full border border-border/50 px-4 py-2 text-sm text-muted-foreground hover:text-foreground hover:border-border transition-colors"
                >
                  <action.icon className="h-4 w-4" strokeWidth={1.5} />
                  {action.label}
                </button>
              )
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}
