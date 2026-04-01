"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import {
  User,
  Blocks,
  Bot,
  Shield,
  AlertTriangle,
  Smartphone,
  Globe,
  LogOut,
  Copy,
  Check,
  Download,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";

const ECHO_PERSONALITIES = [
  { id: "gentle", label: "温柔内敛", description: "安静、体贴，像一位默默陪伴的朋友" },
  { id: "positive", label: "积极阳光", description: "热情、鼓励，总是给你正能量" },
  { id: "rational", label: "克制理性", description: "冷静、客观，用逻辑帮你分析问题" },
];

export default function SettingsPage() {
  const router = useRouter();
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [displayName, setDisplayName] = useState("...");
  const [echoPersonality, setEchoPersonality] = useState(() => {
    if (typeof window === "undefined") return "gentle";
    return localStorage.getItem("echo-personality") || "gentle";
  });
  const [signingOut, setSigningOut] = useState(false);
  const [syncToken, setSyncToken] = useState<string | null>(null);
  const [tokenCopied, setTokenCopied] = useState(false);

  // Dynamic connector status
  const [hasBrowsingData, setHasBrowsingData] = useState(false);
  const [hasIOSData, setHasIOSData] = useState(false);
  const [connectorLoading, setConnectorLoading] = useState(true);

  // Account operation states
  const [showClearDialog, setShowClearDialog] = useState(false);
  const [clearConfirmText, setClearConfirmText] = useState("");
  const [clearing, setClearing] = useState(false);
  const [deleteStep, setDeleteStep] = useState(0);
  const [deleteEmailConfirm, setDeleteEmailConfirm] = useState("");
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data: { user } }) => {
      if (!user) return;

      setUserEmail(user.email ?? null);
      setDisplayName(
        user.user_metadata?.display_name || user.email?.split("@")[0] || "用户"
      );

      const { data: profile } = (await supabase
        .from("profiles")
        .select("sync_token")
        .eq("id", user.id)
        .single()) as { data: { sync_token: string } | null };

      if (profile?.sync_token) setSyncToken(profile.sync_token);

      const { count: browsingCount } = await supabase
        .from("browsing_sessions")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id);
      setHasBrowsingData((browsingCount || 0) > 0);

      const { count: iosCount } = await supabase
        .from("data_points")
        .select("id", { count: "exact", head: true })
        .eq("user_id", user.id)
        .eq("source", "iphone");
      setHasIOSData((iosCount || 0) > 0);
      setConnectorLoading(false);
    });
  }, []);

  const handleSignOut = async () => {
    setSigningOut(true);
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/auth/login");
  };

  const handleClearData = async () => {
    if (clearConfirmText !== "删除") return;
    setClearing(true);
    try {
      const res = await fetch("/api/account/clear-data", { method: "POST" });
      if (res.ok) {
        setShowClearDialog(false);
        setClearConfirmText("");
        window.location.reload();
      }
    } finally {
      setClearing(false);
    }
  };

  const handleExportData = () => {
    window.open("/api/account/export", "_blank");
  };

  const handleDeleteAccount = async () => {
    setDeleting(true);
    try {
      window.open("/api/account/export", "_blank");
      const res = await fetch("/api/account/delete", { method: "POST" });
      if (res.ok) router.push("/auth/login");
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div className="min-h-screen">
      <div className="px-12 pt-12 pb-10">
        <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">设置</h1>
        <p className="text-base text-muted-foreground mt-2">管理你的账户和偏好</p>
      </div>

      <div className="px-12 pb-12 space-y-8 max-w-3xl">
        {/* Account Section */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <User className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">账户</h2>
          </div>
          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div><p className="text-sm text-foreground">邮箱</p><p className="text-xs text-muted-foreground">{userEmail ?? "未登录"}</p></div>
          </div>
          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div><p className="text-sm text-foreground">显示名称</p><p className="text-xs text-muted-foreground">{displayName}</p></div>
          </div>
          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div><p className="text-sm text-foreground">当前计划</p><p className="text-xs text-muted-foreground">免费版</p></div>
          </div>
          <div className="flex items-center justify-between py-3 last:border-0">
            <div><p className="text-sm text-foreground">退出登录</p><p className="text-xs text-muted-foreground">登出当前账户</p></div>
            <button onClick={handleSignOut} disabled={signingOut} className="flex items-center gap-2 border border-border/50 text-muted-foreground rounded-full px-4 py-2 text-sm hover:text-foreground hover:border-border transition-colors disabled:opacity-50">
              <LogOut className="h-4 w-4" strokeWidth={1.5} />
              {signingOut ? "退出中…" : "退出"}
            </button>
          </div>
        </div>

        {/* Data Sources Section */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Blocks className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">数据源</h2>
          </div>
          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div className="flex items-center gap-3">
              <Globe className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
              <div><p className="text-sm text-foreground">浏览器扩展</p><p className="text-xs text-muted-foreground">追踪浏览活动和屏幕时间</p></div>
            </div>
            <div className="flex items-center gap-2">
              {connectorLoading ? (
                <span className="text-xs text-muted-foreground">检查中...</span>
              ) : (
                <>
                  <div className={`h-2 w-2 rounded-full ${hasBrowsingData ? "bg-emerald-500" : "bg-muted-foreground/30"}`} />
                  <span className={`text-xs ${hasBrowsingData ? "text-emerald-600 font-medium" : "text-muted-foreground"}`}>
                    {hasBrowsingData ? "已连接" : "未连接"}
                  </span>
                </>
              )}
            </div>
          </div>

          {syncToken && (
            <div className="py-3 border-b border-border/30">
              <div className="flex items-center justify-between">
                <div><p className="text-sm text-foreground">同步令牌</p><p className="text-xs text-muted-foreground">在浏览器扩展中输入此令牌以同步数据</p></div>
                <button onClick={() => { navigator.clipboard.writeText(syncToken); setTokenCopied(true); setTimeout(() => setTokenCopied(false), 2000); }} className="flex items-center gap-2 border border-border/50 text-muted-foreground rounded-full px-4 py-2 text-sm hover:text-foreground hover:border-border transition-colors">
                  {tokenCopied ? (<><Check className="h-3.5 w-3.5" strokeWidth={1.5} />已复制</>) : (<><Copy className="h-3.5 w-3.5" strokeWidth={1.5} />复制</>)}
                </button>
              </div>
              <code className="block mt-2 text-xs text-muted-foreground bg-muted/50 rounded-lg px-3 py-2 font-mono break-all select-all">{syncToken}</code>
            </div>
          )}

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div className="flex items-center gap-3">
              <Smartphone className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
              <div><p className="text-sm text-foreground">手机 App</p><p className="text-xs text-muted-foreground">同步健康和活动数据</p></div>
            </div>
            <div className="flex items-center gap-2">
              {connectorLoading ? (
                <span className="text-xs text-muted-foreground">检查中...</span>
              ) : (
                <>
                  <div className={`h-2 w-2 rounded-full ${hasIOSData ? "bg-emerald-500" : "bg-muted-foreground/30"}`} />
                  <span className={`text-xs ${hasIOSData ? "text-emerald-600 font-medium" : "text-muted-foreground"}`}>
                    {hasIOSData ? "已连接" : "未连接"}
                  </span>
                </>
              )}
            </div>
          </div>

          <div className="pt-3 last:border-0">
            <Link href="/dashboard/connectors" className="text-sm text-primary hover:opacity-80 transition-opacity">管理所有连接器 →</Link>
          </div>
        </div>

        {/* Echo AI Section */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Bot className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">Echo AI</h2>
          </div>
          <p className="text-sm text-muted-foreground mb-4">选择 Echo 的性格风格</p>
          <div className="space-y-2">
            {ECHO_PERSONALITIES.map((p) => {
              const isSelected = echoPersonality === p.id;
              return (
                <button key={p.id} onClick={() => { setEchoPersonality(p.id); localStorage.setItem("echo-personality", p.id); }}
                  className={`w-full flex items-center gap-4 rounded-xl border p-4 text-left transition-all duration-200 ${isSelected ? "border-primary/60 bg-primary/5" : "border-border/40 bg-background hover:border-border hover:shadow-sm"}`}>
                  <div className={`h-4 w-4 rounded-full border-2 flex items-center justify-center transition-colors ${isSelected ? "border-primary" : "border-muted-foreground/40"}`}>
                    {isSelected && <div className="h-2 w-2 rounded-full bg-primary" />}
                  </div>
                  <div><p className="text-sm text-foreground">{p.label}</p><p className="text-xs text-muted-foreground">{p.description}</p></div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Privacy Section */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Shield className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">隐私</h2>
          </div>
          <div className="py-3 border-b border-border/30">
            <p className="text-sm text-foreground mb-1">数据说明</p>
            <p className="text-xs text-muted-foreground leading-relaxed">
              所有数据仅存储在你的设备和你的 Supabase 账户中。ToDay 不会将你的个人数据分享给任何第三方。你可以随时导出或删除所有数据。
            </p>
          </div>
          <div className="flex items-center justify-between py-3">
            <div><p className="text-sm text-foreground">导出数据</p><p className="text-xs text-muted-foreground">下载你的所有数据（JSON 格式）</p></div>
            <button onClick={handleExportData} className="flex items-center gap-2 border border-border/50 text-muted-foreground rounded-full px-4 py-2 text-sm hover:text-foreground hover:border-border transition-colors">
              <Download className="h-4 w-4" strokeWidth={1.5} />导出
            </button>
          </div>
        </div>

        {/* Danger Zone */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <AlertTriangle className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">危险区域</h2>
          </div>

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div><p className="text-sm text-foreground">清除所有数据</p><p className="text-xs text-muted-foreground">删除所有记录，账户本身保留</p></div>
            <button onClick={() => setShowClearDialog(true)} className="border border-destructive/30 text-destructive rounded-lg px-4 py-2 text-sm font-medium hover:bg-destructive/10 transition-colors">清除数据</button>
          </div>

          {showClearDialog && (
            <div className="py-3 border-b border-border/30 bg-destructive/5 rounded-lg px-4 -mx-2">
              <p className="text-sm text-foreground mb-2">此操作将清除你的所有浏览记录、健康数据和心情记录。</p>
              <p className="text-xs text-muted-foreground mb-3">请输入「删除」以确认：</p>
              <div className="flex gap-2">
                <input type="text" value={clearConfirmText} onChange={(e) => setClearConfirmText(e.target.value)} placeholder="删除" className="flex-1 rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-destructive/20" />
                <button onClick={handleClearData} disabled={clearConfirmText !== "删除" || clearing} className="rounded-lg bg-destructive text-destructive-foreground px-4 py-2 text-sm font-medium disabled:opacity-50">{clearing ? "清除中..." : "确认清除"}</button>
                <button onClick={() => { setShowClearDialog(false); setClearConfirmText(""); }} className="rounded-lg border border-border px-4 py-2 text-sm text-muted-foreground hover:text-foreground">取消</button>
              </div>
            </div>
          )}

          <div className="flex items-center justify-between py-3 last:border-0">
            <div><p className="text-sm text-foreground">删除账户</p><p className="text-xs text-muted-foreground">永久删除你的账户和所有相关数据（30 天冷却期）</p></div>
            <button onClick={() => setDeleteStep(1)} className="border border-destructive/30 text-destructive rounded-lg px-4 py-2 text-sm font-medium hover:bg-destructive/10 transition-colors">删除账户</button>
          </div>

          {deleteStep === 1 && (
            <div className="py-3 bg-destructive/5 rounded-lg px-4 -mx-2">
              <p className="text-sm text-foreground mb-2 font-medium">确定要删除账户吗？</p>
              <p className="text-xs text-muted-foreground mb-3">删除后有 30 天冷却期，期间登录可撤销。到期后账户和所有数据将被永久删除。我们会先导出你的数据。</p>
              <div className="flex gap-2">
                <button onClick={() => setDeleteStep(2)} className="rounded-lg bg-destructive text-destructive-foreground px-4 py-2 text-sm font-medium">继续</button>
                <button onClick={() => setDeleteStep(0)} className="rounded-lg border border-border px-4 py-2 text-sm text-muted-foreground hover:text-foreground">取消</button>
              </div>
            </div>
          )}

          {deleteStep === 2 && (
            <div className="py-3 bg-destructive/5 rounded-lg px-4 -mx-2">
              <p className="text-sm text-foreground mb-2">请输入你的邮箱以确认：</p>
              <div className="flex gap-2">
                <input type="email" value={deleteEmailConfirm} onChange={(e) => setDeleteEmailConfirm(e.target.value)} placeholder={userEmail || "your@email.com"} className="flex-1 rounded-lg border border-border bg-background px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-destructive/20" />
                <button onClick={() => { if (deleteEmailConfirm === userEmail) setDeleteStep(3); }} disabled={deleteEmailConfirm !== userEmail} className="rounded-lg bg-destructive text-destructive-foreground px-4 py-2 text-sm font-medium disabled:opacity-50">确认</button>
                <button onClick={() => { setDeleteStep(0); setDeleteEmailConfirm(""); }} className="rounded-lg border border-border px-4 py-2 text-sm text-muted-foreground hover:text-foreground">取消</button>
              </div>
            </div>
          )}

          {deleteStep === 3 && (
            <div className="py-3 bg-destructive/5 rounded-lg px-4 -mx-2">
              <p className="text-sm text-foreground mb-2 font-medium">最后确认</p>
              <p className="text-xs text-muted-foreground mb-3">点击确认后，你的数据将被导出下载，账户将进入 30 天删除倒计时。</p>
              <div className="flex gap-2">
                <button onClick={handleDeleteAccount} disabled={deleting} className="rounded-lg bg-destructive text-destructive-foreground px-4 py-2 text-sm font-medium disabled:opacity-50">{deleting ? "处理中..." : "确认删除"}</button>
                <button onClick={() => { setDeleteStep(0); setDeleteEmailConfirm(""); }} className="rounded-lg border border-border px-4 py-2 text-sm text-muted-foreground hover:text-foreground">取消</button>
              </div>
            </div>
          )}
        </div>

        <div className="text-center pb-4"><p className="text-xs text-muted-foreground">ToDay v0.5.0</p></div>
      </div>
    </div>
  );
}
