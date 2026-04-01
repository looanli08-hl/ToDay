"use client";

import { useState, useEffect } from "react";
import {
  Moon,
  Footprints,
  MapPin,
  Monitor,
  Heart,
  Coffee,
  Home,
  Briefcase,
  ChevronLeft,
  ChevronRight,
  CalendarDays,
  Clock,
} from "lucide-react";
import { cn } from "@/lib/utils";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface TimelineEvent {
  id: string;
  time: string;
  label: string;
  icon: typeof Moon;
  duration?: string;
  type:
    | "sleep"
    | "commute"
    | "location"
    | "screen"
    | "mood"
    | "exercise"
    | "meal";
}

interface BrowsingSession {
  domain: string;
  label: string;
  category: string;
  title: string;
  startTime: number;
  endTime: number;
  duration: number;
}

// ---------------------------------------------------------------------------
// Mock data — used as fallback when no real data exists
// ---------------------------------------------------------------------------

const mockEvents: TimelineEvent[] = [];

const stats = [
  { label: "步数", value: "--" },
  { label: "运动", value: "--" },
  { label: "屏幕", value: "--" },
  { label: "心情", value: "--" },
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

function formatTimeFromTimestamp(ts: number): string {
  const d = new Date(ts);
  return d.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false });
}

async function fetchBrowsingSessions(date: string): Promise<BrowsingSession[]> {
  try {
    const res = await fetch(`/api/data?date=${date}&source=browser-extension`);
    if (!res.ok) return [];
    const json = await res.json();

    // Extract sessions from data points
    const allSessions: BrowsingSession[] = [];

    for (const point of json.data) {
      const val = point.value as { sessions?: BrowsingSession[] };
      if (val.sessions && Array.isArray(val.sessions)) {
        allSessions.push(...val.sessions);
      }
    }

    // Deduplicate by startTime (sync may send duplicates)
    const seen = new Set<number>();
    const unique = allSessions.filter((s) => {
      if (seen.has(s.startTime)) return false;
      seen.add(s.startTime);
      return s.duration >= 10;
    });

    // Sort by start time (earliest first)
    return unique.sort((a, b) => a.startTime - b.startTime);
  } catch {
    return [];
  }
}

// ---------------------------------------------------------------------------
// DateStrip — horizontal row of selectable dates
// ---------------------------------------------------------------------------

function DateStrip({
  selectedDate,
  onSelect,
}: {
  selectedDate: Date;
  onSelect: (d: Date) => void;
}) {
  const today = new Date();

  // Generate 7 days centered on today
  const dates = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(today);
    d.setDate(today.getDate() - 3 + i);
    return d;
  });

  const shiftDates = (direction: number) => {
    const d = new Date(selectedDate);
    d.setDate(d.getDate() + direction);
    onSelect(d);
  };

  return (
    <div className="flex items-center gap-1">
      <button
        onClick={() => shiftDates(-1)}
        className="p-1 text-muted-foreground hover:text-foreground transition-colors"
      >
        <ChevronLeft className="h-4 w-4" strokeWidth={1.5} />
      </button>
      <div className="flex gap-1">
        {dates.map((d) => {
          const isToday = d.toDateString() === today.toDateString();
          const isSelected = d.toDateString() === selectedDate.toDateString();
          return (
            <button
              key={d.toISOString()}
              onClick={() => onSelect(d)}
              className={cn(
                "flex flex-col items-center rounded-lg px-3 py-2 text-xs transition-colors",
                isSelected
                  ? "bg-foreground text-background"
                  : "text-muted-foreground hover:bg-accent"
              )}
            >
              <span className="font-medium">{d.getDate()}</span>
              {isToday && <span className="text-[11px]">今</span>}
            </button>
          );
        })}
      </div>
      <button
        onClick={() => shiftDates(1)}
        className="p-1 text-muted-foreground hover:text-foreground transition-colors"
      >
        <ChevronRight className="h-4 w-4" strokeWidth={1.5} />
      </button>
    </div>
  );
}

// ---------------------------------------------------------------------------
// EmptyState — shown when there are no events for the selected date
// ---------------------------------------------------------------------------

function EmptyState() {
  return (
    <div className="flex flex-col items-center justify-center py-16">
      <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-muted">
        <Clock className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
      </div>
      <h3 className="font-display text-lg text-foreground mb-1">
        这一天还没有记录
      </h3>
      <p className="text-sm text-muted-foreground">
        连接数据源后，活动会自动出现在这里
      </p>
    </div>
  );
}

// ---------------------------------------------------------------------------
// TimelinePage — main page component
// ---------------------------------------------------------------------------

export default function TimelinePage() {
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [browsingSessions, setBrowsingSessions] = useState<BrowsingSession[]>([]);
  const [expandedBlocks, setExpandedBlocks] = useState<Set<string>>(new Set());

  const today = new Date();
  const isToday = selectedDate.toDateString() === today.toDateString();

  // Fetch browsing sessions when date changes
  useEffect(() => {
    const dateStr = selectedDate.toISOString().split("T")[0];
    fetchBrowsingSessions(dateStr).then(setBrowsingSessions);
  }, [selectedDate]);

  // Merge browsing sessions into the timeline as real events
  const phoneEvents = mockEvents;

  // Group consecutive browsing sessions by category into blocks
  const browsingBlocks: {
    id: string;
    category: string;
    startTime: number;
    endTime: number;
    totalDuration: number;
    sessions: BrowsingSession[];
  }[] = [];

  for (const session of browsingSessions) {
    const lastBlock = browsingBlocks[browsingBlocks.length - 1];
    // Merge into last block if same category and within 5 minutes
    if (
      lastBlock &&
      lastBlock.category === session.category &&
      session.startTime - lastBlock.endTime < 5 * 60 * 1000
    ) {
      lastBlock.endTime = session.endTime;
      lastBlock.totalDuration += session.duration;
      lastBlock.sessions.push(session);
    } else {
      browsingBlocks.push({
        id: `block-${browsingBlocks.length}`,
        category: session.category,
        startTime: session.startTime,
        endTime: session.endTime,
        totalDuration: session.duration,
        sessions: [session],
      });
    }
  }

  // Convert blocks to timeline events
  const browsingEvents: TimelineEvent[] = browsingBlocks.map((block) => ({
    id: block.id,
    time: formatTimeFromTimestamp(block.startTime),
    label: block.category,
    icon: Monitor,
    duration: formatDuration(block.totalDuration),
    type: "screen" as const,
  }));

  // Merge and sort all events by time
  const events = [...phoneEvents, ...browsingEvents].sort((a, b) =>
    a.time.localeCompare(b.time)
  );

  const dateStr = selectedDate.toLocaleDateString("zh-CN", {
    year: "numeric",
    month: "long",
    day: "numeric",
    weekday: "long",
  });

  return (
    <div className="min-h-screen">
      {/* Header */}
      <div className="px-12 pt-12 pb-6">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="font-display text-2xl font-normal tracking-tight text-foreground">
              时间线
            </h1>
            <p className="text-sm text-muted-foreground mt-1">
              你的一天，按时间展开
            </p>
          </div>
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <CalendarDays
              className="h-4 w-4 text-muted-foreground"
              strokeWidth={1.5}
            />
            <span>{dateStr}</span>
          </div>
        </div>
      </div>

      <div className="px-12 pb-12 space-y-8">
        {/* Date Strip */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <DateStrip selectedDate={selectedDate} onSelect={setSelectedDate} />
        </div>

        {/* Timeline Body */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          {events.length === 0 && browsingSessions.length === 0 ? (
            <EmptyState />
          ) : (
            <div>
              {events.map((event, index) => {
                const isLast = index === events.length - 1;
                const block = event.id.startsWith("block-")
                  ? browsingBlocks.find((b) => b.id === event.id)
                  : null;
                const isExpanded = expandedBlocks.has(event.id);

                return (
                  <div key={event.id}>
                    <div
                      className={cn(
                        "flex items-start gap-4",
                        block && "cursor-pointer"
                      )}
                      onClick={() => {
                        if (!block) return;
                        setExpandedBlocks((prev) => {
                          const next = new Set(prev);
                          if (next.has(event.id)) next.delete(event.id);
                          else next.add(event.id);
                          return next;
                        });
                      }}
                    >
                      <span className="w-12 text-xs font-mono text-muted-foreground pt-0.5 text-right shrink-0">
                        {event.time}
                      </span>

                      <div className="relative flex flex-col items-center shrink-0">
                        <div className="h-2 w-2 rounded-full bg-muted-foreground/30 mt-1.5" />
                        {(!isLast || isExpanded) && (
                          <div className="w-px flex-1 bg-border/60 mt-1" />
                        )}
                      </div>

                      <div className="flex-1 pb-5">
                        <div className="flex items-center gap-2">
                          <event.icon
                            className="h-4 w-4 text-muted-foreground"
                            strokeWidth={1.5}
                          />
                          <span className="text-sm text-foreground">
                            {event.label}
                          </span>
                          {event.duration && (
                            <span className="text-xs text-muted-foreground ml-auto font-mono">
                              {event.duration}
                            </span>
                          )}
                        </div>
                        {block && (
                          <p className="text-[11px] text-muted-foreground mt-1 ml-6">
                            {block.sessions.length} 个网站{isExpanded ? "" : " · 点击展开"}
                          </p>
                        )}
                      </div>
                    </div>

                    {/* Expanded sessions */}
                    {block && isExpanded && (
                      <div className="ml-[76px] mb-4 border-l border-border/40 pl-4 space-y-0">
                        {block.sessions.map((session, si) => (
                          <div
                            key={si}
                            className="flex items-center gap-3 py-1.5"
                          >
                            <span className="text-[11px] font-mono text-muted-foreground w-24 shrink-0">
                              {formatTimeFromTimestamp(session.startTime)} - {formatTimeFromTimestamp(session.endTime)}
                            </span>
                            <span className="text-xs text-foreground flex-1 truncate">
                              {session.title && session.title !== session.domain
                                ? session.title
                                : session.label || session.domain}
                            </span>
                            <span className="text-[11px] text-muted-foreground font-mono shrink-0">
                              {formatDuration(session.duration)}
                            </span>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Browsing Detail — collapsible summary */}
        {browsingSessions.length > 0 && (
          <div className="border border-border/40 bg-card rounded-xl p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Monitor className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                <h2 className="font-display text-lg text-foreground">浏览详情</h2>
              </div>
              <div className="flex items-center gap-3 text-xs text-muted-foreground">
                <span>{browsingSessions.length} 个时段</span>
                <span className="font-mono">{formatDuration(browsingSessions.reduce((sum, s) => sum + s.duration, 0))}</span>
              </div>
            </div>
            <div>
              {browsingSessions.map((session, i) => (
                <div key={i} className="flex items-center gap-4 py-2 border-b border-border/30 last:border-0">
                  <span className="w-24 text-[11px] font-mono text-muted-foreground shrink-0">
                    {formatTimeFromTimestamp(session.startTime)} - {formatTimeFromTimestamp(session.endTime)}
                  </span>
                  <span className="text-sm text-foreground flex-1 truncate">
                    {session.title && session.title !== session.domain
                      ? `${session.label} · ${session.title}`
                      : session.label || session.domain}
                  </span>
                  <span className="text-xs text-muted-foreground font-mono shrink-0">
                    {formatDuration(session.duration)}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Stats Bar */}
        {events.length > 0 && (
          <div className="border border-border/40 bg-card rounded-xl p-6">
            <p className="text-xs font-medium text-muted-foreground mb-4">
              今日统计
            </p>
            <div className="grid grid-cols-4 gap-4">
              {stats.map((stat) => (
                <div key={stat.label} className="text-center">
                  <p className="font-display text-lg text-foreground">
                    {stat.value}
                  </p>
                  <p className="text-xs text-muted-foreground mt-1">
                    {stat.label}
                  </p>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
