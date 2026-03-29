"use client";

import { Card } from "@/components/ui/card";
import {
  Activity,
  Footprints,
  Moon,
  Smile,
  Lightbulb,
  BarChart3,
  Grid3x3,
} from "lucide-react";

// --- Mock Data ---

const weeklyStats = [
  {
    label: "日均屏幕时间",
    value: "4h 12m",
    sub: "较上周 -8%",
    icon: Activity,
  },
  {
    label: "日均步数",
    value: "8,240",
    sub: "较上周 +12%",
    icon: Footprints,
  },
  {
    label: "日均睡眠",
    value: "7.2h",
    sub: "较上周 +0.3h",
    icon: Moon,
  },
  {
    label: "心情分布",
    value: "偏积极",
    sub: "开心 4 天 / 平静 3 天",
    icon: Smile,
  },
];

// Heatmap data: 7 days x 24 hours, intensity 0-1
const heatmapData: number[][] = [
  // Mon
  [0, 0, 0, 0, 0, 0, 0.1, 0.3, 0.5, 0.8, 0.9, 0.6, 0.3, 0.5, 0.8, 0.7, 0.4, 0.2, 0.1, 0.4, 0.7, 0.5, 0.2, 0],
  // Tue
  [0, 0, 0, 0, 0, 0, 0, 0.2, 0.6, 0.9, 0.8, 0.7, 0.4, 0.6, 0.9, 0.6, 0.3, 0.2, 0.1, 0.3, 0.8, 0.6, 0.1, 0],
  // Wed
  [0, 0, 0, 0, 0, 0, 0.1, 0.4, 0.7, 0.6, 0.5, 0.4, 0.2, 0.4, 0.6, 0.5, 0.3, 0.1, 0.1, 0.5, 0.6, 0.3, 0.1, 0],
  // Thu
  [0, 0, 0, 0, 0, 0, 0.1, 0.3, 0.5, 0.7, 0.8, 0.6, 0.3, 0.5, 0.7, 0.6, 0.4, 0.3, 0.2, 0.4, 0.7, 0.5, 0.2, 0],
  // Fri
  [0, 0, 0, 0, 0, 0, 0, 0.2, 0.4, 0.6, 0.5, 0.4, 0.2, 0.3, 0.5, 0.4, 0.2, 0.1, 0.1, 0.2, 0.4, 0.3, 0.1, 0],
  // Sat
  [0, 0, 0, 0, 0, 0, 0, 0, 0.1, 0.2, 0.3, 0.3, 0.2, 0.1, 0.2, 0.2, 0.1, 0.1, 0.2, 0.3, 0.4, 0.3, 0.1, 0],
  // Sun
  [0, 0, 0, 0, 0, 0, 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.3, 0.2, 0.3, 0.4, 0.3, 0.2, 0.2, 0.4, 0.5, 0.4, 0.2, 0],
];

const dayLabels = ["一", "二", "三", "四", "五", "六", "日"];

// Category trends: weekly stacked bar data
const categoryTrends = [
  { day: "一", 效率: 135, 娱乐: 70, 社交: 35, 学习: 20, 其他: 12 },
  { day: "二", 效率: 150, 娱乐: 85, 社交: 40, 学习: 15, 其他: 20 },
  { day: "三", 效率: 110, 娱乐: 60, 社交: 30, 学习: 25, 其他: 20 },
  { day: "四", 效率: 135, 娱乐: 70, 社交: 35, 学习: 20, 其他: 12 },
  { day: "五", 效率: 90, 娱乐: 50, 社交: 20, 学习: 15, 其他: 15 },
  { day: "六", 效率: 30, 娱乐: 50, 社交: 20, 学习: 10, 其他: 10 },
  { day: "日", 效率: 50, 娱乐: 60, 社交: 25, 学习: 15, 其他: 15 },
];

const categoryColors: Record<string, string> = {
  效率: "bg-primary/80",
  娱乐: "bg-primary/55",
  社交: "bg-primary/40",
  学习: "bg-primary/25",
  其他: "bg-primary/15",
};

const insights = [
  {
    text: "你的效率工具使用集中在上午，建议保持这个习惯",
    tag: "习惯洞察",
  },
  {
    text: "本周社交媒体使用比上周减少了 15%",
    tag: "趋势变化",
  },
  {
    text: "睡眠时间趋于稳定，平均 7.2 小时",
    tag: "健康指标",
  },
];

// --- Helpers ---

function getHeatmapOpacity(value: number): string {
  if (value === 0) return "bg-primary/5";
  if (value <= 0.15) return "bg-primary/10";
  if (value <= 0.3) return "bg-primary/20";
  if (value <= 0.5) return "bg-primary/35";
  if (value <= 0.7) return "bg-primary/50";
  if (value <= 0.85) return "bg-primary/65";
  return "bg-primary/80";
}

// --- Component ---

export default function AnalyticsPage() {
  const categoryKeys = ["效率", "娱乐", "社交", "学习", "其他"] as const;
  const maxStackedTotal = Math.max(
    ...categoryTrends.map((d) =>
      categoryKeys.reduce(
        (sum, key) => sum + (d[key as keyof typeof d] as number),
        0
      )
    )
  );

  return (
    <div className="min-h-screen">
      {/* Header */}
      <div className="px-12 pt-12 pb-10">
        <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
          数据分析
        </h1>
        <p className="text-base text-muted-foreground mt-2">
          发现你的生活规律
        </p>
      </div>

      <div className="px-12 pb-12 space-y-8">
        {/* Weekly Overview - 4 Stat Cards */}
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {weeklyStats.map((card) => (
            <Card
              key={card.label}
              className="border border-border/40 bg-card rounded-xl p-6 hover:shadow-sm transition-shadow duration-300"
            >
              <div className="flex items-start justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">{card.label}</p>
                  <p className="font-display text-2xl font-normal text-foreground mt-2">
                    {card.value}
                  </p>
                  <p className="text-xs text-muted-foreground/60 mt-1">
                    {card.sub}
                  </p>
                </div>
                <card.icon
                  className="h-4 w-4 text-muted-foreground/25"
                  strokeWidth={1.5}
                />
              </div>
            </Card>
          ))}
        </div>

        {/* Category Trends */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-6">
            <BarChart3 className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">分类趋势</h2>
          </div>

          {/* Legend */}
          <div className="flex flex-wrap gap-4 mb-4">
            {categoryKeys.map((key) => (
              <div key={key} className="flex items-center gap-2">
                <div
                  className={`h-2.5 w-2.5 rounded-full ${categoryColors[key]}`}
                />
                <span className="text-xs text-muted-foreground">{key}</span>
              </div>
            ))}
          </div>

          {/* Stacked bars */}
          <div className="flex items-end justify-between gap-3 h-44">
            {categoryTrends.map((d) => {
              const total = categoryKeys.reduce(
                (sum, key) => sum + (d[key as keyof typeof d] as number),
                0
              );
              return (
                <div
                  key={d.day}
                  className="flex flex-col items-center gap-2 flex-1"
                >
                  <span className="text-xs text-muted-foreground">
                    {Math.floor(total / 60)}h
                  </span>
                  <div
                    className="w-full flex flex-col-reverse rounded-lg overflow-hidden"
                    style={{
                      height: `${(total / maxStackedTotal) * 128}px`,
                    }}
                  >
                    {categoryKeys.map((key) => {
                      const val = d[key as keyof typeof d] as number;
                      return (
                        <div
                          key={key}
                          className={`w-full ${categoryColors[key]} transition-all duration-500`}
                          style={{
                            height: `${(val / total) * 100}%`,
                          }}
                        />
                      );
                    })}
                  </div>
                  <span className="text-[11px] text-muted-foreground">
                    {d.day}
                  </span>
                </div>
              );
            })}
          </div>
        </Card>

        {/* AI Insights */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-6">
            <Lightbulb className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">智能洞察</h2>
            <span className="text-xs text-muted-foreground ml-auto">
              由 Echo 生成
            </span>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            {insights.map((insight, i) => (
              <div
                key={i}
                className="rounded-xl border border-border/40 bg-background p-4"
              >
                <span className="inline-block text-[11px] text-muted-foreground rounded-full border border-border/50 px-2.5 py-0.5 mb-3">
                  {insight.tag}
                </span>
                <p className="text-sm text-foreground/80 leading-relaxed">
                  {insight.text}
                </p>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}
