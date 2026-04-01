"use client";

import { useState, useEffect } from "react";
import { cn } from "@/lib/utils";

// ---------------------------------------------------------------------------
// Types & Data
// ---------------------------------------------------------------------------

interface Memo {
  id: string;
  content: string;
  createdAt: Date;
}

const mockMemos: Memo[] = [];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function groupByDate(memos: Memo[]): { label: string; memos: Memo[] }[] {
  const groups: Record<string, Memo[]> = {};
  const today = new Date().toDateString();
  const yesterday = new Date(Date.now() - 86400000).toDateString();

  for (const memo of memos) {
    const dateStr = new Date(memo.createdAt).toDateString();
    let label: string;
    if (dateStr === today) label = "今天";
    else if (dateStr === yesterday) label = "昨天";
    else
      label = new Date(memo.createdAt).toLocaleDateString("zh-CN", {
        month: "long",
        day: "numeric",
      });

    if (!groups[label]) groups[label] = [];
    groups[label].push(memo);
  }

  return Object.entries(groups).map(([label, memos]) => ({
    label,
    memos: memos.sort(
      (a, b) => b.createdAt.getTime() - a.createdAt.getTime()
    ),
  }));
}

function formatTime(date: Date): string {
  return date.toLocaleTimeString("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

function formatHeaderDate(): string {
  const now = new Date();
  return now.toLocaleDateString("zh-CN", { month: "numeric", day: "numeric" });
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

export default function CapturePage() {
  const [memos, setMemos] = useState<Memo[]>(() => {
    if (typeof window === "undefined") return [];
    try {
      const saved = localStorage.getItem("capture-memos");
      if (saved) {
        return JSON.parse(saved).map((m: Memo) => ({
          ...m,
          createdAt: new Date(m.createdAt),
        }));
      }
    } catch {}
    return [];
  });
  const [inputValue, setInputValue] = useState("");

  useEffect(() => {
    localStorage.setItem("capture-memos", JSON.stringify(memos));
  }, [memos]);

  const grouped = groupByDate(memos);

  function handleSubmit() {
    if (!inputValue.trim()) return;
    const newMemo: Memo = {
      id: crypto.randomUUID(),
      content: inputValue.trim(),
      createdAt: new Date(),
    };
    setMemos((prev) => [newMemo, ...prev]);
    setInputValue("");
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  }

  return (
    <div className="min-h-screen">
      {/* Header */}
      <div className="px-12 pt-12 pb-10 flex items-baseline justify-between">
        <div>
          <h1 className="font-display text-2xl font-normal tracking-tight text-foreground">
            捕捉
          </h1>
          <p className="text-sm text-muted-foreground mt-2">
            随时记录灵感、想法和此刻的心情
          </p>
        </div>
        <span className="text-sm text-muted-foreground">{formatHeaderDate()}</span>
      </div>

      <div className="px-12 pb-12 space-y-8">
        {/* Input Card */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <textarea
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="写点什么..."
            rows={3}
            className="w-full bg-transparent text-sm text-foreground placeholder:text-muted-foreground/50 outline-none resize-none"
          />
          <div className="flex justify-end mt-3">
            <button
              onClick={handleSubmit}
              disabled={!inputValue.trim()}
              className={cn(
                "text-sm font-medium transition-opacity",
                inputValue.trim()
                  ? "text-primary hover:opacity-80"
                  : "text-muted-foreground/40 cursor-default"
              )}
            >
              记录 ↵
            </button>
          </div>
        </div>

        {/* Memo Stream */}
        <div className="space-y-6">
          {grouped.map((group) => (
            <div key={group.label}>
              <p className="text-xs font-medium text-muted-foreground mb-3 mt-2">
                {group.label}
              </p>
              <div className="space-y-3">
                {group.memos.map((memo) => (
                  <div
                    key={memo.id}
                    className="border border-border/40 bg-card rounded-xl px-5 py-4 hover:shadow-sm transition-shadow"
                  >
                    <p className="text-sm text-foreground whitespace-pre-wrap">
                      {memo.content}
                    </p>
                    <p className="text-[11px] text-muted-foreground font-mono text-right mt-2">
                      {formatTime(memo.createdAt)}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
