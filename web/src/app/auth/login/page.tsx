"use client";

import { useState, useEffect, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import Link from "next/link";

function LoginContent() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [showResend, setShowResend] = useState(false);
  const [resendLoading, setResendLoading] = useState(false);
  const [resendSent, setResendSent] = useState(false);
  const router = useRouter();
  const searchParams = useSearchParams();

  useEffect(() => {
    const errorParam = searchParams.get("error");
    if (errorParam) {
      setError(errorParam);
    }
  }, [searchParams]);

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setShowResend(false);
    setLoading(true);

    try {
      const supabase = createClient();
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) {
        if (error.message.toLowerCase().includes("email not confirmed")) {
          setError("请先验证你的邮箱");
          setShowResend(true);
        } else {
          setError(error.message);
        }
        setLoading(false);
        return;
      }
      router.push("/dashboard");
      router.refresh();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "登录失败");
      setLoading(false);
    }
  }

  async function handleResend() {
    setResendLoading(true);
    try {
      const supabase = createClient();
      await supabase.auth.resend({ type: "signup", email });
      setResendSent(true);
    } catch {
      setError("发送失败，请稍后重试");
    } finally {
      setResendLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex items-center justify-center gap-1 mb-8">
          <span className="font-display text-2xl text-foreground">ToDay</span>
          <span className="text-primary text-2xl">.</span>
        </div>

        {/* Card */}
        <div className="rounded-xl bg-card border border-border/40 p-8">
          <h1 className="font-display text-xl text-foreground mb-1">欢迎回来</h1>
          <p className="text-sm text-muted-foreground mb-6">登录你的 ToDay 账户</p>

          {/* Email Form */}
          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">邮箱</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="your@email.com"
                required
                className="w-full rounded-lg border border-border bg-background px-4 py-2.5 text-sm placeholder:text-muted-foreground/50 outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40 transition-all"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">密码</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                className="w-full rounded-lg border border-border bg-background px-4 py-2.5 text-sm placeholder:text-muted-foreground/50 outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40 transition-all"
              />
              <div className="mt-1.5 text-right">
                <Link href="/auth/reset-password" className="text-xs text-muted-foreground hover:text-primary transition-colors">
                  忘记密码？
                </Link>
              </div>
            </div>

            {error && (
              <div className="text-sm text-destructive bg-destructive/10 rounded-lg px-3 py-2">
                <p>{error}</p>
                {showResend && !resendSent && (
                  <button
                    type="button"
                    onClick={handleResend}
                    disabled={resendLoading}
                    className="mt-1 text-xs underline hover:no-underline disabled:opacity-50"
                  >
                    {resendLoading ? "发送中..." : "重新发送验证邮件"}
                  </button>
                )}
                {resendSent && (
                  <p className="mt-1 text-xs">验证邮件已重新发送，请查收</p>
                )}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-primary text-primary-foreground rounded-lg px-4 py-2.5 text-sm font-medium hover:opacity-90 transition-opacity disabled:opacity-50"
            >
              {loading ? "登录中..." : "登录"}
            </button>
          </form>
        </div>

        <div className="mt-4 space-y-2">
          <p className="text-center text-xs text-muted-foreground">
            还没有账户？{" "}
            <Link href="/auth/register" className="text-primary font-medium hover:underline">
              注册
            </Link>
          </p>
          <p className="text-center text-xs text-muted-foreground/50">
            手机号登录即将开放
          </p>
        </div>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense>
      <LoginContent />
    </Suspense>
  );
}
