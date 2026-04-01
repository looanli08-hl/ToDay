"use client";

import { useState, useEffect } from "react";
import { cn } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";

interface Memo {
  id: string;
  content: string;
  createdAt: Date;
}

function groupByDate(memos: Memo[]): { label: string; memos: Memo[] }[] {
  const groups: Record<string, Memo[]> = {};
  const today = new Date().toDateString();
  const yesterday = new Date(Date.now() - 86400000).toDateString();

  for (const memo of memos) {
    const dateStr = new Date(memo.createdAt).toDateString();
    let label: string;
    if (dateStr === today) label = "今天";
    else if (dateStr === yesterday) label = "昨天";
    else label = new Date(memo.createdAt).toLocaleDateString("zh-CN", { month: "long", day: "numeric" });
    if (!groups[label]) groups[label] = [];
    groups[label].push(memo);
  }

  return Object.entries(groups).map(([label, memos]) => ({
    label,
    memos: memos.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()),
  }));
}

function formatTime(date: Date): string {
  return date.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false });
}

function formatHeaderDate(): string {
  return new Date().toLocaleDateString("zh-CN", { month: "numeric", day: "numeric" });
}

export default function CapturePage() {
  const [memos, setMemos] = useState<Memo[]>([]);
  const [inputValue, setInputValue] = useState("");
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data: { user } }: { data: { user: any } }) => {
      if (!user) { setLoading(false); return; }

      const { data } = await supabase
        .from("mood_records")
        .select("id, note, created_at")
        .eq("user_id", user.id)
        .eq("emoji", "📝")
        .eq("name", "捕捉")
        .order("created_at", { ascending: false })
        .limit(200) as { data: { id: string; note: string | null; created_at: string }[] | null };

      if (data) {
        setMemos(data.filter((r) => r.note).map((r) => ({
          id: r.id,
          content: r.note!,
          createdAt: new Date(r.created_at),
        })));
      }
      setLoading(false);
    });
  }, []);

  const grouped = groupByDate(memos);

  async function handleSubmit() {
    if (!inputValue.trim() || submitting) return;
    setSubmitting(true);

    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { setSubmitting(false); return; }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { data, error } = await (supabase as any)
      .from("mood_records")
      .insert({ user_id: user.id, emoji: "📝", name: "捕捉", note: inputValue.trim() })
      .select("id, created_at")
      .single() as { data: { id: string; created_at: string } | null; error: unknown };

    if (!error && data) {
      setMemos((prev) => [{ id: data.id, content: inputValue.trim(), createdAt: new Date(data.created_at) }, ...prev]);
      setInputValue("");
    }
    setSubmitting(false);
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); handleSubmit(); }
  }

  return (
    <div className="min-h-screen">
      <div className="px-12 pt-12 pb-10 flex items-baseline justify-between">
        <div>
          <h1 className="font-display text-2xl font-normal tracking-tight text-foreground">捕捉</h1>
          <p className="text-sm text-muted-foreground mt-2">随时记录灵感、想法和此刻的心情</p>
        </div>
        <span className="text-sm text-muted-foreground">{formatHeaderDate()}</span>
      </div>

      <div className="px-12 pb-12 space-y-8">
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <textarea value={inputValue} onChange={(e) => setInputValue(e.target.value)} onKeyDown={handleKeyDown} placeholder="写点什么..." rows={3} className="w-full bg-transparent text-sm text-foreground placeholder:text-muted-foreground/50 outline-none resize-none" />
          <div className="flex justify-end mt-3">
            <button onClick={handleSubmit} disabled={!inputValue.trim() || submitting}
              className={cn("text-sm font-medium transition-opacity", inputValue.trim() && !submitting ? "text-primary hover:opacity-80" : "text-muted-foreground/40 cursor-default")}>
              {submitting ? "保存中..." : "记录 ↵"}
            </button>
          </div>
        </div>

        {loading && (
          <div className="space-y-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="border border-border/40 bg-card rounded-xl px-5 py-4 animate-pulse">
                <div className="h-4 bg-muted rounded w-3/4 mb-2" />
                <div className="h-3 bg-muted rounded w-16 ml-auto" />
              </div>
            ))}
          </div>
        )}

        {!loading && (
          <div className="space-y-6">
            {grouped.map((group) => (
              <div key={group.label}>
                <p className="text-xs font-medium text-muted-foreground mb-3 mt-2">{group.label}</p>
                <div className="space-y-3">
                  {group.memos.map((memo) => (
                    <div key={memo.id} className="border border-border/40 bg-card rounded-xl px-5 py-4 hover:shadow-sm transition-shadow">
                      <p className="text-sm text-foreground whitespace-pre-wrap">{memo.content}</p>
                      <p className="text-[11px] text-muted-foreground font-mono text-right mt-2">{formatTime(memo.createdAt)}</p>
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
