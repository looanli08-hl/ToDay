"use client";

import { useState } from "react";
import { cn } from "@/lib/utils";

// ---------------------------------------------------------------------------
// Types & Data
// ---------------------------------------------------------------------------

interface Memo {
  id: string;
  content: string;
  createdAt: Date;
}

const mockMemos: Memo[] = [
  {
    id: "1",
    content: "项目进展顺利，Echo 的流式对话体验很好",
    createdAt: new Date(Date.now() - 2 * 3600000),
  },
  {
    id: "2",
    content:
      "想到一个功能：浏览器扩展可以记录 YouTube 视频标题，这样 Echo 就能知道用户在学什么",
    createdAt: new Date(Date.now() - 6 * 3600000),
  },
  {
    id: "3",
    content: "跟 Claude 合作开发效率真的很高，一天做完了平时一周的量",
    createdAt: new Date(Date.now() - 24 * 3600000),
  },
  {
    id: "4",
    content: "ToDay 的定位越来越清晰了：不只是记录工具，是一个生活统筹中心",
    createdAt: new Date(Date.now() - 25 * 3600000),
  },
  {
    id: "5",
    content: "OpenClaw 的开源策略很值得学习，先做好产品再开源",
    createdAt: new Date(Date.now() - 48 * 3600000),
  },
  {
    id: "6",
    content: "设计系统定好以后，新页面做起来快多了，一致性也好",
    createdAt: new Date(Date.now() - 50 * 3600000),
  },
];

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
  const [memos, setMemos] = useState<Memo[]>(mockMemos);
  const [inputValue, setInputValue] = useState("");

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
