"use client";

import { useEffect, useState } from "react";
import { Card } from "@/components/ui/card";
import {
  Layers,
  ArrowDown,
  ArrowUp,
  Clock,
  Globe,
  BarChart3,
  MonitorSmartphone,
} from "lucide-react";

// --- Types ---

interface ScreenTimeData {
  today: {
    totalMinutes: number;
    categories: { name: string; minutes: number }[];
    topSites: { domain: string; title: string; minutes: number }[];
    hourly: number[];
  };
  yesterday: { totalMinutes: number };
  weekly: { day: string; date: string; minutes: number }[];
}

// --- Helpers ---

function formatDuration(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m}m`;
  return `${h}h ${m}m`;
}

const CATEGORY_COLORS: Record<string, string> = {
  "效率": "bg-primary/70",
  "娱乐": "bg-primary/55",
  "社交": "bg-primary/45",
  "通讯": "bg-primary/40",
  "学习": "bg-primary/35",
  "购物": "bg-primary/30",
  "搜索": "bg-primary/25",
  "AI工具": "bg-primary/20",
  "其他": "bg-primary/15",
};

// --- Component ---

export default function ScreenTimePage() {
  const [data, setData] = useState<ScreenTimeData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const today = new Date().toISOString().split("T")[0];
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const token = new URLSearchParams(window.location.search).get("token") || "";
    const tokenParam = token ? `&token=${token}` : "";

    fetch(`/api/screen-time?date=${today}&tz=${tz}${tokenParam}`)
      .then((res) => {
        if (!res.ok) return null;
        return res.json();
      })
      .then((json) => {
        if (json) setData(json);
        setLoading(false);
      })
      .catch(() => {
        setLoading(false);
      });
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen">
        <div className="px-12 pt-12 pb-10">
          <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
            屏幕时间
          </h1>
          <p className="text-base text-muted-foreground mt-2">
            了解你的数字生活习惯
          </p>
        </div>
        <div className="px-12 pb-12 space-y-8">
          {[1, 2, 3].map((i) => (
            <Card
              key={i}
              className="border border-border/40 bg-card rounded-xl p-6 h-40 animate-pulse"
            >
              <div className="h-4 w-32 bg-muted rounded mb-4" />
              <div className="h-8 w-24 bg-muted rounded" />
            </Card>
          ))}
        </div>
      </div>
    );
  }

  // Empty state
  if (!data || data.today.totalMinutes === 0) {
    return (
      <div className="min-h-screen">
        <div className="px-12 pt-12 pb-10">
          <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
            屏幕时间
          </h1>
          <p className="text-base text-muted-foreground mt-2">
            了解你的数字生活习惯
          </p>
        </div>
        <div className="px-12 pb-12">
          <Card className="border border-border/40 bg-card rounded-xl p-12 text-center">
            <MonitorSmartphone
              className="h-10 w-10 text-muted-foreground/40 mx-auto mb-4"
              strokeWidth={1}
            />
            <p className="text-foreground font-display text-lg">
              还没有浏览数据
            </p>
            <p className="text-sm text-muted-foreground mt-2">
              安装浏览器扩展并配置同步令牌，开始记录你的屏幕时间
            </p>
          </Card>
        </div>
      </div>
    );
  }

  const { today, yesterday, weekly } = data;
  const diff = yesterday.totalMinutes - today.totalMinutes;
  const diffPercent =
    yesterday.totalMinutes > 0
      ? Math.round((Math.abs(diff) / yesterday.totalMinutes) * 100)
      : 0;
  const isLess = diff > 0;

  const maxCategory = Math.max(...today.categories.map((c) => c.minutes), 1);
  const maxHourly = Math.max(...today.hourly, 1);
  const maxWeekly = Math.max(...weekly.map((d) => d.minutes), 1);

  return (
    <div className="min-h-screen">
      {/* Header */}
      <div className="px-12 pt-12 pb-10">
        <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
          屏幕时间
        </h1>
        <p className="text-base text-muted-foreground mt-2">
          了解你的数字生活习惯
        </p>
      </div>

      <div className="px-12 pb-12 space-y-8">
        {/* Today's Summary */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Clock className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">今日总览</h2>
          </div>
          <div className="flex items-end gap-4">
            <span className="font-display text-4xl font-normal text-foreground">
              {formatDuration(today.totalMinutes)}
            </span>
            {yesterday.totalMinutes > 0 && (
              <div className="flex items-center gap-1 pb-1.5">
                {isLess ? (
                  <ArrowDown className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                ) : (
                  <ArrowUp className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                )}
                <span className="text-sm text-muted-foreground">
                  比昨天{isLess ? "少" : "多"} {diffPercent}%
                </span>
              </div>
            )}
          </div>
        </Card>

        {/* Two-column layout */}
        <div className="grid gap-4 xl:grid-cols-2">
          {/* Category Breakdown */}
          <Card className="border border-border/40 bg-card rounded-xl p-6">
            <div className="flex items-center gap-2 mb-6">
              <Layers className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
              <h2 className="font-display text-lg text-foreground">分类用时</h2>
            </div>
            <div className="space-y-4">
              {today.categories.map((cat) => (
                <div key={cat.name}>
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-sm text-foreground">{cat.name}</span>
                    <span className="text-xs text-muted-foreground">
                      {formatDuration(cat.minutes)}
                    </span>
                  </div>
                  <div className="h-2 w-full rounded-full bg-muted">
                    <div
                      className={`h-full rounded-full ${CATEGORY_COLORS[cat.name] || "bg-primary/15"} transition-all duration-500`}
                      style={{
                        width: `${(cat.minutes / maxCategory) * 100}%`,
                      }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </Card>

          {/* Top Sites */}
          <Card className="border border-border/40 bg-card rounded-xl p-6">
            <div className="flex items-center gap-2 mb-6">
              <Globe className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
              <h2 className="font-display text-lg text-foreground">常用站点</h2>
            </div>
            <div className="space-y-0">
              {today.topSites.map((site, i) => (
                <div
                  key={site.domain}
                  className="flex items-center gap-3 py-3 border-b border-border/40 last:border-0"
                >
                  <span className="text-xs text-muted-foreground w-5 text-right">
                    {i + 1}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-foreground truncate">
                      {site.domain}
                    </p>
                    <p className="text-[11px] text-muted-foreground truncate">
                      {site.title}
                    </p>
                  </div>
                  <span className="text-xs text-muted-foreground whitespace-nowrap">
                    {formatDuration(site.minutes)}
                  </span>
                </div>
              ))}
            </div>
          </Card>
        </div>

        {/* Hourly Distribution */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-6">
            <BarChart3 className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">每小时分布</h2>
          </div>
          <div className="flex items-end gap-1 h-32">
            {today.hourly.map((val, i) => (
              <div
                key={i}
                className="flex flex-col items-center flex-1 gap-1.5 group"
              >
                <div className="w-full flex flex-col items-center justify-end h-24">
                  <div
                    className="w-full rounded-lg bg-primary/70 transition-all duration-500 min-h-[2px]"
                    style={{
                      height:
                        maxHourly > 0
                          ? `${Math.max((val / maxHourly) * 100, val > 0 ? 4 : 0)}%`
                          : "0%",
                    }}
                  />
                </div>
                {i % 3 === 0 ? (
                  <span className="text-[11px] text-muted-foreground">
                    {i.toString().padStart(2, "0")}
                  </span>
                ) : (
                  <span className="text-[11px] text-transparent">00</span>
                )}
              </div>
            ))}
          </div>
        </Card>

        {/* Weekly Trend */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-6">
            <BarChart3 className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">本周趋势</h2>
          </div>
          <div className="flex items-end justify-between gap-3 h-36">
            {weekly.map((d) => (
              <div
                key={d.date}
                className="flex flex-col items-center gap-2 flex-1"
              >
                <span className="text-xs text-muted-foreground">
                  {d.minutes > 0 ? formatDuration(d.minutes) : "—"}
                </span>
                <div className="w-full flex flex-col items-center justify-end h-24">
                  <div
                    className="w-full rounded-lg bg-primary/70 transition-all duration-500"
                    style={{
                      height:
                        d.minutes > 0
                          ? `${(d.minutes / maxWeekly) * 100}%`
                          : "2px",
                    }}
                  />
                </div>
                <span className="text-[11px] text-muted-foreground">
                  {d.day}
                </span>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}
