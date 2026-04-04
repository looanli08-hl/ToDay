"use client";

import { useState, useEffect } from "react";
import { useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { getAuthCallbackUrl, getFriendlyAuthError } from "@/lib/auth";
import Link from "next/link";
import { Suspense } from "react";

function VerifyContent() {
  const searchParams = useSearchParams();
  const email = searchParams.get("email") || "";
  const [resendLoading, setResendLoading] = useState(false);
  const [resendSent, setResendSent] = useState(false);
  const [cooldown, setCooldown] = useState(0);
  const [error, setError] = useState("");

  useEffect(() => {
    if (cooldown <= 0) return;
    const timer = setTimeout(() => setCooldown(cooldown - 1), 1000);
    return () => clearTimeout(timer);
  }, [cooldown]);

  async function handleResend() {
    if (cooldown > 0 || !email) return;
    setError("");
    setResendLoading(true);
    try {
      const supabase = createClient();
      const { error } = await supabase.auth.resend({
        type: "signup",
        email,
        options: {
          emailRedirectTo: getAuthCallbackUrl(),
        },
      });

      if (error) {
        setError(getFriendlyAuthError(error.message));
        return;
      }

      setResendSent(true);
      setCooldown(60);
    } catch (err: unknown) {
      setError(err instanceof Error ? getFriendlyAuthError(err.message) : "发送失败，请稍后再试");
    } finally {
      setResendLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex items-center justify-center gap-1 mb-8">
          <span className="font-display text-2xl text-foreground">Attune</span>
          <span className="text-primary text-2xl">.</span>
        </div>

        {/* Card */}
        <div className="rounded-xl bg-card border border-border/40 p-8 text-center">
          {/* Mail icon */}
          <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-primary/10">
            <svg className="h-6 w-6 text-primary" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75" />
            </svg>
          </div>

          <h1 className="font-display text-xl text-foreground mb-2">验证你的邮箱</h1>
          <p className="text-sm text-muted-foreground mb-1">
            我们已发送验证链接到
          </p>
          {email && (
            <p className="text-sm font-medium text-foreground mb-6">{email}</p>
          )}
          <p className="text-xs text-muted-foreground mb-6">
            请查收邮件并点击链接完成注册
          </p>

          <button
            onClick={handleResend}
            disabled={resendLoading || cooldown > 0}
            className="w-full rounded-lg border border-border bg-background px-4 py-2.5 text-sm font-medium text-foreground hover:bg-accent transition-colors disabled:opacity-50"
          >
            {resendLoading
              ? "发送中..."
              : cooldown > 0
                ? `重新发送 (${cooldown}s)`
                : resendSent
                  ? "再次发送"
                  : "重新发送验证邮件"}
          </button>

          {error && (
            <p className="mt-3 rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive">{error}</p>
          )}
        </div>

        <p className="text-center text-xs text-muted-foreground mt-4">
          <Link href="/auth/login" className="text-primary font-medium hover:underline">
            返回登录
          </Link>
        </p>
      </div>
    </div>
  );
}

export default function VerifyPage() {
  return (
    <Suspense fallback={
      <div className="flex min-h-screen items-center justify-center bg-background">
        <p className="text-sm text-muted-foreground">加载中...</p>
      </div>
    }>
      <VerifyContent />
    </Suspense>
  );
}
