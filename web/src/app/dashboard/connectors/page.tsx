"use client";

import { useState, useEffect } from "react";
import { Card } from "@/components/ui/card";
import { createClient } from "@/lib/supabase/client";
import { Blocks, Smartphone, Globe, Copy, Check, ExternalLink } from "lucide-react";

export default function ConnectorsPage() {
  const [syncToken, setSyncToken] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [hasIOSData, setHasIOSData] = useState(false);
  const [hasBrowsingData, setHasBrowsingData] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data: { user } }: { data: { user: any } }) => {
      if (!user) return;

      // Get sync token
      const { data: profile } = await supabase
        .from("profiles")
        .select("sync_token")
        .eq("id", user.id)
        .single() as { data: { sync_token: string } | null };

      if (profile?.sync_token) {
        setSyncToken(profile.sync_token);

        // Check if user has any browsing data
        const { count: browsingCount } = await supabase
          .from("browsing_sessions")
          .select("id", { count: "exact", head: true })
          .eq("user_id", user.id);

        setHasBrowsingData((browsingCount || 0) > 0);
      }

      // Check if user has any iOS data
      const { count: iosCount } = await supabase
        .from("data_points")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id)
        .eq("source", "iphone");

      setHasIOSData((iosCount || 0) > 0);
      setLoading(false);
    });
  }, []);

  function handleCopy() {
    if (syncToken) {
      navigator.clipboard.writeText(syncToken);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  }

  return (
    <div className="px-12 pt-12 pb-12">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <Blocks className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
          <h1 className="font-display text-2xl tracking-tight text-foreground">连接器</h1>
        </div>
        <p className="text-sm text-muted-foreground">
          连接你的设备，让 Echo 开始了解你的生活
        </p>
      </div>

      <div className="grid gap-6 max-w-2xl">
        {/* Browser Extension */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-50">
              <Globe className="h-5 w-5 text-amber-600" strokeWidth={1.5} />
            </div>
            <div className="flex-1">
              <h3 className="font-display text-base text-foreground">浏览器扩展</h3>
              <p className="text-xs text-muted-foreground">记录浏览活动和屏幕时间</p>
            </div>
            {!loading && (
              <div className="flex items-center gap-1.5">
                <div className={`h-2 w-2 rounded-full ${hasBrowsingData ? "bg-emerald-500" : "bg-muted-foreground/30"}`} />
                <span className={`text-xs font-medium ${hasBrowsingData ? "text-emerald-600" : "text-muted-foreground"}`}>
                  {hasBrowsingData ? "已连接" : "未连接"}
                </span>
              </div>
            )}
          </div>

          {hasBrowsingData ? (
            <p className="text-sm text-muted-foreground">浏览器扩展正在记录你的浏览活动。你可以在「屏幕时间」页面查看数据。</p>
          ) : (
            <div className="space-y-4">
              <div className="rounded-xl bg-background p-4">
                <p className="text-sm font-medium text-foreground mb-3">安装步骤：</p>
                <ol className="space-y-2 text-sm text-muted-foreground">
                  <li className="flex gap-2">
                    <span className="text-primary font-medium">1.</span>
                    下载浏览器扩展（从项目 GitHub 的 extension 文件夹）
                  </li>
                  <li className="flex gap-2">
                    <span className="text-primary font-medium">2.</span>
                    在 Chrome 中打开 chrome://extensions，开启「开发者模式」
                  </li>
                  <li className="flex gap-2">
                    <span className="text-primary font-medium">3.</span>
                    点击「加载已解压的扩展程序」，选择 extension 文件夹
                  </li>
                  <li className="flex gap-2">
                    <span className="text-primary font-medium">4.</span>
                    点击扩展图标，粘贴下方的同步令牌
                  </li>
                </ol>
              </div>

              {syncToken && (
                <div className="rounded-xl bg-background p-4">
                  <p className="text-xs text-muted-foreground mb-2">你的同步令牌</p>
                  <div className="flex items-center gap-2">
                    <code className="flex-1 text-xs font-mono bg-muted rounded-lg px-3 py-2 text-foreground/70 truncate">
                      {syncToken}
                    </code>
                    <button
                      onClick={handleCopy}
                      className="flex items-center gap-1.5 rounded-lg border border-border px-3 py-2 text-xs font-medium text-muted-foreground hover:text-foreground transition-colors"
                    >
                      {copied ? <Check className="h-3.5 w-3.5 text-emerald-500" /> : <Copy className="h-3.5 w-3.5" />}
                      {copied ? "已复制" : "复制"}
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}
        </Card>

        {/* iOS App */}
        <Card className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-3 mb-5">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-50">
              <Smartphone className="h-5 w-5 text-blue-600" strokeWidth={1.5} />
            </div>
            <div className="flex-1">
              <h3 className="font-display text-base text-foreground">iOS App</h3>
              <p className="text-xs text-muted-foreground">记录健康、运动、心情、位置数据</p>
            </div>
            {!loading && (
              <div className="flex items-center gap-1.5">
                <div className={`h-2 w-2 rounded-full ${hasIOSData ? "bg-emerald-500" : "bg-muted-foreground/30"}`} />
                <span className={`text-xs font-medium ${hasIOSData ? "text-emerald-600" : "text-muted-foreground"}`}>
                  {hasIOSData ? "已连接" : "未连接"}
                </span>
              </div>
            )}
          </div>

          {hasIOSData ? (
            <p className="text-sm text-muted-foreground">iOS App 正在同步你的健康和生活数据。</p>
          ) : (
            <div className="rounded-xl bg-background p-4">
              <p className="text-sm text-muted-foreground mb-3">
                在 App Store 搜索「ToDay」下载 iOS App，登录同一账号后数据会自动同步。
              </p>
              <p className="text-xs text-muted-foreground/60">
                App 会请求 HealthKit 和位置权限来记录你的生活数据。
              </p>
            </div>
          )}
        </Card>

        {/* Coming Soon */}
        <Card className="border border-dashed border-border/50 bg-transparent rounded-xl p-6">
          <div className="text-center">
            <p className="text-sm font-medium text-muted-foreground mb-1">更多连接器即将推出</p>
            <p className="text-xs text-muted-foreground/60">Spotify、微信支付、小米手环、B 站...</p>
          </div>
        </Card>
      </div>
    </div>
  );
}
