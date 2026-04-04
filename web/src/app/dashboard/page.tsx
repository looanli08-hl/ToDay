"use client";

import { useState, useEffect } from "react";
import { Card } from "@/components/ui/card";
import { Check, Copy, Globe, Key, PanelRight } from "lucide-react";
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

export default function DashboardPage() {
  const [userName, setUserName] = useState("");
  const [syncToken, setSyncToken] = useState<string | null>(null);
  const [tokenCopied, setTokenCopied] = useState(false);
  const [extensionConnected, setExtensionConnected] = useState(false);
  const [loading, setLoading] = useState(true);
  const greeting = getGreeting();
  const now = new Date();
  const dateStr = now.toLocaleDateString("zh-CN", {
    month: "long",
    day: "numeric",
    weekday: "long",
  });

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data: { user } }: { data: { user: any } }) => {
      if (!user) {
        setLoading(false);
        return;
      }

      setUserName(
        user.user_metadata?.display_name ||
          user.email?.split("@")[0] ||
          ""
      );

      // Fetch sync token from profile
      const { data: profile } = (await supabase
        .from("profiles")
        .select("sync_token")
        .eq("id", user.id)
        .single()) as { data: { sync_token: string } | null };

      if (profile?.sync_token) setSyncToken(profile.sync_token);

      // Check if extension is connected (has browsing sessions)
      const { count } = await supabase
        .from("browsing_sessions")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id);
      setExtensionConnected((count || 0) > 0);

      setLoading(false);
    });
  }, []);

  const handleCopyToken = () => {
    if (!syncToken) return;
    navigator.clipboard.writeText(syncToken);
    setTokenCopied(true);
    setTimeout(() => setTokenCopied(false), 2000);
  };

  return (
    <div className="min-h-screen">
      {/* Hero Section */}
      <div className="px-12 pt-14 pb-10">
        <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
          {greeting}{userName ? `，${userName}` : ""}
        </h1>
        <p className="text-base text-muted-foreground mt-2">{dateStr}</p>
      </div>

      <div className="px-12 pb-12 space-y-8 max-w-3xl">
        {/* Connection Status */}
        <Card className="border border-border/30 bg-card rounded-2xl p-6">
          <div className="flex items-center gap-3">
            <div className={`h-2.5 w-2.5 rounded-full ${extensionConnected ? "bg-emerald-500" : "bg-muted-foreground/30"}`} />
            <div>
              <p className={`text-sm font-medium ${extensionConnected ? "text-emerald-600" : "text-muted-foreground"}`}>
                {loading ? (
                  <span className="inline-block w-24 h-4 bg-muted-foreground/10 rounded animate-pulse" />
                ) : extensionConnected ? "扩展已连接" : "扩展尚未连接"}
              </p>
              <p className="text-xs text-muted-foreground/60 mt-0.5">
                {extensionConnected
                  ? "Attune 浏览器扩展正在同步数据"
                  : "按照以下步骤开始使用 Attune"}
              </p>
            </div>
          </div>
        </Card>

        {/* Get Started Steps */}
        <div>
          <h2 className="font-display text-lg text-foreground mb-4">开始使用 Attune</h2>
          <div className="space-y-4">
            {/* Step 1: Install Extension */}
            <Card className="border border-border/30 bg-card rounded-2xl p-6">
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary text-sm font-semibold">
                  1
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <Globe className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                    <p className="text-sm font-medium text-foreground">安装 Attune 浏览器扩展</p>
                  </div>
                  <p className="text-xs text-muted-foreground leading-relaxed">
                    从 Chrome Web Store 安装 Attune 扩展，它会记录你的浏览域名和时长，帮助 Echo 理解你的数字生活。
                  </p>
                </div>
              </div>
            </Card>

            {/* Step 2: Copy Sync Token */}
            <Card className="border border-border/30 bg-card rounded-2xl p-6">
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary text-sm font-semibold">
                  2
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <Key className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                    <p className="text-sm font-medium text-foreground">复制你的同步令牌</p>
                  </div>
                  <p className="text-xs text-muted-foreground leading-relaxed mb-3">
                    在扩展设置中粘贴此令牌，将浏览数据同步到你的 Attune 账户。
                  </p>
                  {loading ? (
                    <div className="h-10 bg-muted-foreground/10 rounded-lg animate-pulse" />
                  ) : syncToken ? (
                    <div className="flex items-center gap-2">
                      <code className="flex-1 text-xs text-muted-foreground bg-muted/50 rounded-lg px-3 py-2.5 font-mono break-all select-all">
                        {syncToken}
                      </code>
                      <button
                        onClick={handleCopyToken}
                        className="flex items-center gap-1.5 shrink-0 border border-border/50 text-muted-foreground rounded-full px-3.5 py-2 text-xs hover:text-foreground hover:border-border transition-colors"
                      >
                        {tokenCopied ? (
                          <><Check className="h-3.5 w-3.5" strokeWidth={1.5} />已复制</>
                        ) : (
                          <><Copy className="h-3.5 w-3.5" strokeWidth={1.5} />复制</>
                        )}
                      </button>
                    </div>
                  ) : (
                    <p className="text-xs text-muted-foreground/50">加载中...</p>
                  )}
                </div>
              </div>
            </Card>

            {/* Step 3: Open Echo Side Panel */}
            <Card className="border border-border/30 bg-card rounded-2xl p-6">
              <div className="flex items-start gap-4">
                <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary text-sm font-semibold">
                  3
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <PanelRight className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
                    <p className="text-sm font-medium text-foreground">打开 Echo 侧边栏</p>
                  </div>
                  <p className="text-xs text-muted-foreground leading-relaxed">
                    点击浏览器工具栏中的 Attune 图标，在侧边栏中与 Echo 对话。Echo 会基于你的浏览上下文，给出个性化的回应。
                  </p>
                </div>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
}
