"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { getAuthCallbackUrl, getFriendlyAuthError } from "@/lib/auth";
import Link from "next/link";

export default function ResetPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      const supabase = createClient();
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: getAuthCallbackUrl(),
      });

      if (error) {
        setError(getFriendlyAuthError(error.message));
        return;
      }

      setSent(true);
    } catch (err: unknown) {
      setError(err instanceof Error ? getFriendlyAuthError(err.message) : "发送失败");
    } finally {
      setLoading(false);
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
          {sent ? (
            <div className="text-center">
              <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-primary/10">
                <svg className="h-6 w-6 text-primary" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75" />
                </svg>
              </div>
              <h1 className="font-display text-xl text-foreground mb-2">查收邮件</h1>
              <p className="text-sm text-muted-foreground mb-1">
                密码重置链接已发送到
              </p>
              <p className="text-sm font-medium text-foreground mb-4">{email}</p>
              <p className="text-xs text-muted-foreground">
                点击邮件中的链接重置密码
              </p>
            </div>
          ) : (
            <>
              <h1 className="font-display text-xl text-foreground mb-1">重置密码</h1>
              <p className="text-sm text-muted-foreground mb-6">输入你的邮箱，我们将发送重置链接</p>

              <form onSubmit={handleSubmit} className="space-y-4">
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

                {error && (
                  <p className="text-sm text-destructive bg-destructive/10 rounded-lg px-3 py-2">{error}</p>
                )}

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full bg-primary text-primary-foreground rounded-lg px-4 py-2.5 text-sm font-medium hover:opacity-90 transition-opacity disabled:opacity-50"
                >
                  {loading ? "发送中..." : "发送重置链接"}
                </button>
              </form>
            </>
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
