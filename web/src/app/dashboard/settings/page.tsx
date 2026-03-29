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
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";

// ---------------------------------------------------------------------------
// Echo Personality Options
// ---------------------------------------------------------------------------

const ECHO_PERSONALITIES = [
  { id: "gentle", label: "温柔内敛", description: "安静、体贴，像一位默默陪伴的朋友" },
  { id: "positive", label: "积极阳光", description: "热情、鼓励，总是给你正能量" },
  { id: "rational", label: "克制理性", description: "冷静、客观，用逻辑帮你分析问题" },
];

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

export default function SettingsPage() {
  const router = useRouter();
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [displayName, setDisplayName] = useState("...");
  const [echoPersonality, setEchoPersonality] = useState("gentle");
  const [signingOut, setSigningOut] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) {
        setUserEmail(user.email ?? null);
        setDisplayName(
          user.user_metadata?.display_name ||
            user.email?.split("@")[0] ||
            "用户"
        );
      }
    });
  }, []);

  const handleSignOut = async () => {
    setSigningOut(true);
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/auth/login");
  };

  return (
    <div className="min-h-screen">
      {/* Header */}
      <div className="px-12 pt-12 pb-10">
        <h1 className="font-display text-4xl font-normal tracking-tight text-foreground">
          设置
        </h1>
        <p className="text-base text-muted-foreground mt-2">
          管理你的账户和偏好
        </p>
      </div>

      <div className="px-12 pb-12 space-y-8 max-w-3xl">
        {/* Account Section */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <User className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">账户</h2>
          </div>

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div>
              <p className="text-sm text-foreground">邮箱</p>
              <p className="text-xs text-muted-foreground">
                {userEmail ?? "未登录"}
              </p>
            </div>
          </div>

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div>
              <p className="text-sm text-foreground">显示名称</p>
              <p className="text-xs text-muted-foreground">{displayName}</p>
            </div>
          </div>

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div>
              <p className="text-sm text-foreground">当前计划</p>
              <p className="text-xs text-muted-foreground">免费版</p>
            </div>
          </div>

          <div className="flex items-center justify-between py-3 last:border-0">
            <div>
              <p className="text-sm text-foreground">退出登录</p>
              <p className="text-xs text-muted-foreground">
                登出当前账户
              </p>
            </div>
            <button
              onClick={handleSignOut}
              disabled={signingOut}
              className="flex items-center gap-2 border border-border/50 text-muted-foreground rounded-full px-4 py-2 text-sm hover:text-foreground hover:border-border transition-colors disabled:opacity-50"
            >
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
              <div>
                <p className="text-sm text-foreground">浏览器扩展</p>
                <p className="text-xs text-muted-foreground">
                  追踪浏览活动和屏幕时间
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <div className="h-2 w-2 rounded-full bg-muted-foreground/30" />
              <span className="text-xs text-muted-foreground">未连接</span>
            </div>
          </div>

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div className="flex items-center gap-3">
              <Smartphone className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
              <div>
                <p className="text-sm text-foreground">手机 App</p>
                <p className="text-xs text-muted-foreground">
                  同步健康和活动数据
                </p>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <div className="h-2 w-2 rounded-full bg-muted-foreground/30" />
              <span className="text-xs text-muted-foreground">未连接</span>
            </div>
          </div>

          <div className="pt-3 last:border-0">
            <Link
              href="/dashboard/connectors"
              className="text-sm text-primary hover:opacity-80 transition-opacity"
            >
              管理所有连接器 →
            </Link>
          </div>
        </div>

        {/* Echo AI Section */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <Bot className="h-4 w-4 text-muted-foreground" strokeWidth={1.5} />
            <h2 className="font-display text-lg text-foreground">Echo AI</h2>
          </div>

          <p className="text-sm text-muted-foreground mb-4">
            选择 Echo 的性格风格
          </p>

          <div className="space-y-2">
            {ECHO_PERSONALITIES.map((p) => {
              const isSelected = echoPersonality === p.id;
              return (
                <button
                  key={p.id}
                  onClick={() => setEchoPersonality(p.id)}
                  className={`w-full flex items-center gap-4 rounded-xl border p-4 text-left transition-all duration-200 ${
                    isSelected
                      ? "border-primary/60 bg-primary/5"
                      : "border-border/40 bg-background hover:border-border hover:shadow-sm"
                  }`}
                >
                  <div
                    className={`h-4 w-4 rounded-full border-2 flex items-center justify-center transition-colors ${
                      isSelected
                        ? "border-primary"
                        : "border-muted-foreground/40"
                    }`}
                  >
                    {isSelected && (
                      <div className="h-2 w-2 rounded-full bg-primary" />
                    )}
                  </div>
                  <div>
                    <p className="text-sm text-foreground">{p.label}</p>
                    <p className="text-xs text-muted-foreground">
                      {p.description}
                    </p>
                  </div>
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

          <div className="py-3">
            <p className="text-sm text-foreground mb-1">数据说明</p>
            <p className="text-xs text-muted-foreground leading-relaxed">
              所有数据仅存储在你的设备和你的 Supabase 账户中。ToDay
              不会将你的个人数据分享给任何第三方。你可以随时导出或删除所有数据。
            </p>
          </div>
        </div>

        {/* Danger Zone */}
        <div className="border border-border/40 bg-card rounded-xl p-6">
          <div className="flex items-center gap-2 mb-4">
            <AlertTriangle
              className="h-4 w-4 text-muted-foreground"
              strokeWidth={1.5}
            />
            <h2 className="font-display text-lg text-foreground">危险区域</h2>
          </div>

          <div className="flex items-center justify-between py-3 border-b border-border/30">
            <div>
              <p className="text-sm text-foreground">清除所有数据</p>
              <p className="text-xs text-muted-foreground">
                删除所有记录和设置，此操作不可撤销
              </p>
            </div>
            <button className="border border-destructive/30 text-destructive rounded-lg px-4 py-2 text-sm font-medium hover:bg-destructive/10 transition-colors">
              清除数据
            </button>
          </div>

          <div className="flex items-center justify-between py-3 last:border-0">
            <div>
              <p className="text-sm text-foreground">删除账户</p>
              <p className="text-xs text-muted-foreground">
                永久删除你的账户和所有相关数据
              </p>
            </div>
            <button className="border border-destructive/30 text-destructive rounded-lg px-4 py-2 text-sm font-medium hover:bg-destructive/10 transition-colors">
              删除账户
            </button>
          </div>
        </div>

        {/* Footer */}
        <div className="text-center pb-4">
          <p className="text-xs text-muted-foreground">ToDay v0.5.0</p>
        </div>
      </div>
    </div>
  );
}
