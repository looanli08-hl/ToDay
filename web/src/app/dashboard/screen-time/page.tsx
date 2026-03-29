"use client";

import { Card } from "@/components/ui/card";
import {
  Layers,
  ArrowDown,
  ArrowUp,
  Clock,
  Globe,
  BarChart3,
} from "lucide-react";

// --- Mock Data ---

const todaySummary = {
  total: "4h 32m",
  totalMinutes: 272,
  yesterdayMinutes: 310,
};

const categories = [
  { name: "效率", minutes: 135, color: "bg-primary/70" },
  { name: "娱乐", minutes: 70, color: "bg-primary/50" },
  { name: "社交", minutes: 35, color: "bg-primary/35" },
  { name: "学习", minutes: 20, color: "bg-primary/25" },
  { name: "其他", minutes: 12, color: "bg-primary/15" },
];

const topSites = [
  { domain: "github.com", title: "Pull Requests - ToDay Repository", minutes: 80 },
  { domain: "youtube.com", title: "WWDC 2025 Highlights - SwiftUI...", minutes: 55 },
  { domain: "notion.so", title: "项目计划 / Q2 Roadmap", minutes: 40 },
  { domain: "twitter.com", title: "Home / X", minutes: 30 },
  { domain: "claude.ai", title: "Claude - New conversation", minutes: 15 },
  { domain: "stackoverflow.com", title: "SwiftUI NavigationStack...", minutes: 12 },
  { domain: "figma.com", title: "ToDay - Design System v2", minutes: 10 },
  { domain: "mail.google.com", title: "Inbox (3) - Gmail", minutes: 8 },
];

const hourlyData = [
  0, 0, 0, 0, 0, 0, 2, 8, 15, 28, 35, 20,
  10, 18, 32, 22, 12, 8, 5, 15, 30, 18, 6, 0,
];

const weeklyData = [
  { day: "一", minutes: 280 },
  { day: "二", minutes: 310 },
  { day: "三", minutes: 245 },
  { day: "四", minutes: 272 },
  { day: "五", minutes: 190 },
  { day: "六", minutes: 120 },
  { day: "日", minutes: 165 },
];

// --- Helpers ---

function formatDuration(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m}m`;
  return `${h}h ${m}m`;
}

// --- Component ---

export default function ScreenTimePage() {
  const diff = todaySummary.yesterdayMinutes - todaySummary.totalMinutes;
  const diffPercent = Math.round(
    (Math.abs(diff) / todaySummary.yesterdayMinutes) * 100
  );
  const isLess = diff > 0;

  const maxCategory = Math.max(...categories.map((c) => c.minutes));
  const maxHourly = Math.max(...hourlyData);
  const maxWeekly = Math.max(...weeklyData.map((d) => d.minutes));

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
              {todaySummary.total}
            </span>
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
              {categories.map((cat) => (
                <div key={cat.name}>
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-sm text-foreground">{cat.name}</span>
                    <span className="text-xs text-muted-foreground">
                      {formatDuration(cat.minutes)}
                    </span>
                  </div>
                  <div className="h-2 w-full rounded-full bg-muted">
                    <div
                      className={`h-full rounded-full ${cat.color} transition-all duration-500`}
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
              {topSites.map((site, i) => (
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
            {hourlyData.map((val, i) => (
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
            {weeklyData.map((d) => (
              <div
                key={d.day}
                className="flex flex-col items-center gap-2 flex-1"
              >
                <span className="text-xs text-muted-foreground">
                  {formatDuration(d.minutes)}
                </span>
                <div className="w-full flex flex-col items-center justify-end h-24">
                  <div
                    className="w-full rounded-lg bg-primary/70 transition-all duration-500"
                    style={{
                      height: `${(d.minutes / maxWeekly) * 100}%`,
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
