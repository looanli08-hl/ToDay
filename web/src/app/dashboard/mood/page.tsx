"use client";

import { useState } from "react";
import { Heart } from "lucide-react";

// ---------------------------------------------------------------------------
// Types & Data
// ---------------------------------------------------------------------------

interface MoodOption {
  emoji: string;
  label: string;
}

interface MoodRecord {
  id: string;
  emoji: string;
  label: string;
  note?: string;
  time: string; // HH:mm
  date: string; // display label
  dateKey: string; // grouping key
}

const MOOD_OPTIONS: MoodOption[] = [
  { emoji: "😊", label: "开心" },
  { emoji: "🌿", label: "平静" },
  { emoji: "🎯", label: "专注" },
  { emoji: "😴", label: "疲惫" },
  { emoji: "😔", label: "难过" },
  { emoji: "☺️", label: "满足" },
];

// Mock history data
const MOCK_HISTORY: MoodRecord[] = [
  {
    id: "1",
    emoji: "😊",
    label: "开心",
    note: "项目进展顺利",
    time: "14:30",
    date: "今天",
    dateKey: "today",
  },
  {
    id: "2",
    emoji: "🎯",
    label: "专注",
    time: "10:00",
    date: "今天",
    dateKey: "today",
  },
  {
    id: "3",
    emoji: "😴",
    label: "疲惫",
    note: "加班到很晚",
    time: "23:00",
    date: "昨天",
    dateKey: "yesterday",
  },
  {
    id: "4",
    emoji: "🌿",
    label: "平静",
    note: "早上冥想了",
    time: "08:00",
    date: "昨天",
    dateKey: "yesterday",
  },
  {
    id: "5",
    emoji: "☺️",
    label: "满足",
    note: "完成了一个大功能",
    time: "18:30",
    date: "昨天",
    dateKey: "yesterday",
  },
  {
    id: "6",
    emoji: "😊",
    label: "开心",
    time: "09:00",
    date: "前天",
    dateKey: "2days",
  },
];

// Group records by dateKey
function groupByDate(
  records: MoodRecord[]
): { date: string; records: MoodRecord[] }[] {
  const map = new Map<string, { date: string; records: MoodRecord[] }>();
  for (const r of records) {
    if (!map.has(r.dateKey)) {
      map.set(r.dateKey, { date: r.date, records: [] });
    }
    map.get(r.dateKey)!.records.push(r);
  }
  return Array.from(map.values());
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

export default function MoodPage() {
  const [selectedMood, setSelectedMood] = useState<string | null>(null);
  const [note, setNote] = useState("");

  const grouped = groupByDate(MOCK_HISTORY);

  const handleSave = () => {
    if (!selectedMood) return;
    // In real app, persist to backend
    setSelectedMood(null);
    setNote("");
  };

  return (
    <div className="min-h-screen">
      {/* Header */}
      <div className="px-12 pt-12 pb-10">
        <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
          心情记录
        </h1>
        <p className="text-base text-muted-foreground mt-2">记录此刻的感受</p>
      </div>

      <div className="px-12 pb-12 space-y-8">
        {/* Quick Record Card */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-6">
            <Heart className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">此刻的心情</h2>
          </div>

          {/* Mood Grid */}
          <div className="grid grid-cols-3 sm:grid-cols-6 gap-3">
            {MOOD_OPTIONS.map((mood) => {
              const isSelected = selectedMood === mood.label;
              return (
                <button
                  key={mood.label}
                  onClick={() =>
                    setSelectedMood(isSelected ? null : mood.label)
                  }
                  className={`flex flex-col items-center gap-2 rounded-xl border p-4 transition-all duration-200 ${
                    isSelected
                      ? "border-primary/60 bg-primary/5"
                      : "border-border/40 bg-background hover:border-border hover:shadow-sm"
                  }`}
                >
                  <span className="text-2xl">{mood.emoji}</span>
                  <span className="text-sm text-foreground">{mood.label}</span>
                </button>
              );
            })}
          </div>

          {/* Note Input */}
          <div className="mt-6">
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="写点什么来描述此刻的感受…（可选）"
              rows={3}
              className="w-full rounded-lg border border-border bg-background px-4 py-2.5 text-sm placeholder:text-muted-foreground/50 outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40 transition-all resize-none"
            />
          </div>

          {/* Save Button */}
          <div className="mt-4">
            <button
              onClick={handleSave}
              disabled={!selectedMood}
              className="bg-primary text-primary-foreground rounded-lg px-4 py-2 text-sm font-medium hover:opacity-90 transition-opacity disabled:opacity-40 disabled:cursor-not-allowed"
            >
              记录此刻
            </button>
          </div>
        </div>

        {/* Mood History */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <h2 className="font-display text-lg text-foreground mb-6">
            心情历史
          </h2>

          <div className="space-y-6">
            {grouped.map((group) => (
              <div key={group.date}>
                <p className="text-xs font-medium text-muted-foreground mb-3">
                  {group.date}
                </p>
                <div className="space-y-0">
                  {group.records.map((record) => (
                    <div
                      key={record.id}
                      className="flex items-center gap-4 py-3 border-b border-border/30 last:border-0"
                    >
                      <span className="text-2xl">{record.emoji}</span>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm text-foreground">
                          {record.label}
                        </p>
                        {record.note && (
                          <p className="text-xs text-muted-foreground mt-0.5 truncate">
                            {record.note}
                          </p>
                        )}
                      </div>
                      <span className="text-[11px] text-muted-foreground font-mono">
                        {record.time}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
