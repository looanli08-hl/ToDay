# Auth Flow Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make registration/login/email-verification/password-reset flow work end-to-end so first batch users can self-register.

**Architecture:** Client-side Supabase auth (`@supabase/supabase-js`) for all auth operations. New pages for email verification guidance, forgot password, and update password. Modified callback route to handle email confirmation tokens (not just OAuth PKCE).

**Tech Stack:** Next.js 16 (App Router, `"use client"`), `@supabase/supabase-js` ^2.100, `@supabase/ssr` ^0.9, Tailwind CSS

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `web/src/app/auth/register/page.tsx` | Modify | Remove OAuth, redirect to /auth/verify on success |
| `web/src/app/auth/login/page.tsx` | Modify | Remove OAuth, add forgot password link, handle unverified error |
| `web/src/app/auth/verify/page.tsx` | Create | Post-registration email verification guidance page |
| `web/src/app/auth/callback/route.ts` | Modify | Handle email confirmation + password reset tokens |
| `web/src/app/auth/reset-password/page.tsx` | Create | Forgot password — enter email form |
| `web/src/app/auth/update-password/page.tsx` | Create | Set new password after reset link |

---

### Task 1: Modify Register Page

**Files:**
- Modify: `web/src/app/auth/register/page.tsx`

- [ ] **Step 1: Remove OAuth buttons and divider, redirect to verify page**

Replace the entire file content with:

```tsx
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import Link from "next/link";

export default function RegisterPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  async function handleRegister(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      const supabase = createClient();
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: { display_name: name },
        },
      });

      if (error) {
        setError(error.message);
        setLoading(false);
        return;
      }

      router.push(`/auth/verify?email=${encodeURIComponent(email)}`);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "注册失败");
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
          <h1 className="font-display text-xl text-foreground mb-1">创建账户</h1>
          <p className="text-sm text-muted-foreground mb-6">开始记录你的生活</p>

          {/* Email Form */}
          <form onSubmit={handleRegister} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">名字</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="你的名字"
                required
                className="w-full rounded-lg border border-border bg-background px-4 py-2.5 text-sm placeholder:text-muted-foreground/50 outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40 transition-all"
              />
            </div>
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
                placeholder="至少 6 位"
                required
                minLength={6}
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
              {loading ? "注册中..." : "注册"}
            </button>
          </form>
        </div>

        <div className="mt-4 space-y-2">
          <p className="text-center text-xs text-muted-foreground">
            已有账户？{" "}
            <Link href="/auth/login" className="text-primary font-medium hover:underline">
              登录
            </Link>
          </p>
          <p className="text-center text-xs text-muted-foreground/50">
            手机号注册即将开放
          </p>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Verify the dev server renders the page**

Run: `cd /Users/looanli/Projects/ToDay/web && npm run dev`
Open: `http://localhost:3000/auth/register`
Expected: Form with name/email/password fields, no OAuth buttons, "手机号注册即将开放" at bottom.

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/auth/register/page.tsx
git commit -m "refactor: simplify register page, remove OAuth, redirect to verify"
```

---

### Task 2: Modify Login Page

**Files:**
- Modify: `web/src/app/auth/login/page.tsx`

- [ ] **Step 1: Remove OAuth, add forgot password link, handle unverified email**

Replace the entire file content with:

```tsx
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import Link from "next/link";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [showResend, setShowResend] = useState(false);
  const [resendLoading, setResendLoading] = useState(false);
  const [resendSent, setResendSent] = useState(false);
  const router = useRouter();

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
```

- [ ] **Step 2: Verify the login page renders**

Open: `http://localhost:3000/auth/login`
Expected: Email/password form, "忘记密码？" link, no OAuth buttons, "手机号登录即将开放" at bottom.

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/auth/login/page.tsx
git commit -m "refactor: simplify login page, add forgot password link and unverified email handling"
```

---

### Task 3: Create Verify Email Page

**Files:**
- Create: `web/src/app/auth/verify/page.tsx`

- [ ] **Step 1: Create the verify email guidance page**

```tsx
"use client";

import { useState, useEffect } from "react";
import { useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import Link from "next/link";
import { Suspense } from "react";

function VerifyContent() {
  const searchParams = useSearchParams();
  const email = searchParams.get("email") || "";
  const [resendLoading, setResendLoading] = useState(false);
  const [resendSent, setResendSent] = useState(false);
  const [cooldown, setCooldown] = useState(0);

  useEffect(() => {
    if (cooldown <= 0) return;
    const timer = setTimeout(() => setCooldown(cooldown - 1), 1000);
    return () => clearTimeout(timer);
  }, [cooldown]);

  async function handleResend() {
    if (cooldown > 0 || !email) return;
    setResendLoading(true);
    try {
      const supabase = createClient();
      await supabase.auth.resend({ type: "signup", email });
      setResendSent(true);
      setCooldown(60);
    } catch {
      // silently fail
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
```

- [ ] **Step 2: Verify the page renders**

Open: `http://localhost:3000/auth/verify?email=test@example.com`
Expected: Mail icon, "验证你的邮箱" heading, shows email, resend button.

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/auth/verify/page.tsx
git commit -m "feat: add email verification guidance page"
```

---

### Task 4: Modify Auth Callback

**Files:**
- Modify: `web/src/app/auth/callback/route.ts`

The current callback only handles OAuth PKCE code exchange. Supabase email confirmation uses a different flow — it sends a redirect with `token_hash` and `type` params (or a `code` param depending on the PKCE setting). We need to handle both.

- [ ] **Step 1: Rewrite callback to handle email confirmation and password reset**

Replace the entire file content with:

```ts
import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/client";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);

  // Supabase sends different params depending on the flow:
  // - Email confirmation (PKCE enabled): ?code=xxx
  // - Email confirmation (non-PKCE): ?token_hash=xxx&type=signup
  // - Password reset: ?token_hash=xxx&type=recovery
  // - OAuth: ?code=xxx (with code_verifier cookie)
  const code = searchParams.get("code");
  const tokenHash = searchParams.get("token_hash");
  const type = searchParams.get("type");

  const supabase = createClient();

  // Handle token_hash flow (email confirmation / password reset without PKCE)
  if (tokenHash && type) {
    const { error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type: type as "signup" | "recovery" | "email",
    });

    if (error) {
      return NextResponse.redirect(
        `${origin}/auth/login?error=${encodeURIComponent(error.message)}`
      );
    }

    if (type === "recovery") {
      return NextResponse.redirect(`${origin}/auth/update-password`);
    }

    return NextResponse.redirect(`${origin}/dashboard`);
  }

  // Handle code flow (PKCE — OAuth or email confirmation with PKCE)
  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (error) {
      return NextResponse.redirect(
        `${origin}/auth/login?error=${encodeURIComponent(error.message)}`
      );
    }

    // Check if this was a password recovery flow
    // After code exchange, the session is set. For recovery, redirect to update password.
    const { data: { session } } = await supabase.auth.getSession();
    if (session?.user?.recovery_sent_at) {
      return NextResponse.redirect(`${origin}/auth/update-password`);
    }

    return NextResponse.redirect(`${origin}/dashboard`);
  }

  // No code or token_hash — redirect to login
  return NextResponse.redirect(`${origin}/auth/login`);
}
```

- [ ] **Step 2: Test email confirmation flow**

Register a new account, click the confirmation link in the email.
Expected: Redirects to `/dashboard` after confirmation.

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/auth/callback/route.ts
git commit -m "refactor: auth callback handles email confirmation and password reset flows"
```

---

### Task 5: Create Reset Password Page

**Files:**
- Create: `web/src/app/auth/reset-password/page.tsx`

- [ ] **Step 1: Create the forgot password page**

```tsx
"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";
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
        redirectTo: `${window.location.origin}/auth/callback`,
      });

      if (error) {
        setError(error.message);
        setLoading(false);
        return;
      }

      setSent(true);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "发送失败");
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
```

- [ ] **Step 2: Verify the page renders**

Open: `http://localhost:3000/auth/reset-password`
Expected: Email input form with "重置密码" heading. After submit, shows "查收邮件" confirmation.

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/auth/reset-password/page.tsx
git commit -m "feat: add forgot password page"
```

---

### Task 6: Create Update Password Page

**Files:**
- Create: `web/src/app/auth/update-password/page.tsx`

- [ ] **Step 1: Create the new password form page**

```tsx
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function UpdatePasswordPage() {
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");

    if (password !== confirmPassword) {
      setError("两次输入的密码不一致");
      return;
    }

    setLoading(true);

    try {
      const supabase = createClient();
      const { error } = await supabase.auth.updateUser({ password });

      if (error) {
        setError(error.message);
        setLoading(false);
        return;
      }

      router.push("/dashboard");
      router.refresh();
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "重置失败");
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
          <h1 className="font-display text-xl text-foreground mb-1">设置新密码</h1>
          <p className="text-sm text-muted-foreground mb-6">请输入你的新密码</p>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">新密码</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="至少 6 位"
                required
                minLength={6}
                className="w-full rounded-lg border border-border bg-background px-4 py-2.5 text-sm placeholder:text-muted-foreground/50 outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary/40 transition-all"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">确认密码</label>
              <input
                type="password"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="再次输入密码"
                required
                minLength={6}
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
              {loading ? "保存中..." : "确认新密码"}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Verify the page renders**

Open: `http://localhost:3000/auth/update-password`
Expected: Two password fields with "设置新密码" heading.

- [ ] **Step 3: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add web/src/app/auth/update-password/page.tsx
git commit -m "feat: add update password page for password reset flow"
```

---

### Task 7: Clean Up Empty Confirm Directory

**Files:**
- Delete: `web/src/app/auth/confirm/` (empty directory, unused)

- [ ] **Step 1: Remove the empty directory**

```bash
cd /Users/looanli/Projects/ToDay
rmdir web/src/app/auth/confirm
```

- [ ] **Step 2: Commit**

```bash
cd /Users/looanli/Projects/ToDay
git add -A web/src/app/auth/confirm
git commit -m "chore: remove empty auth/confirm directory"
```

---

### Task 8: End-to-End Verification

- [ ] **Step 1: Start dev server**

```bash
cd /Users/looanli/Projects/ToDay/web && npm run dev
```

- [ ] **Step 2: Test registration flow**

1. Open `http://localhost:3000/auth/register`
2. Enter name, email, password (use a real email you can check)
3. Click "注册"
4. Verify redirect to `/auth/verify?email=xxx`
5. Check email for verification link
6. Click link — should redirect to `/dashboard`

- [ ] **Step 3: Test login with unverified email**

1. Register a new account but don't click verification link
2. Go to `/auth/login`, try to login
3. Verify "请先验证你的邮箱" error + resend button appears

- [ ] **Step 4: Test forgot password flow**

1. From login page, click "忘记密码？"
2. Enter email, submit
3. Verify "查收邮件" confirmation shows
4. Click reset link in email
5. Verify redirect to `/auth/update-password`
6. Enter new password, submit
7. Verify redirect to `/dashboard`

- [ ] **Step 5: Test navigation links**

- Register page "已有账户？登录" → goes to `/auth/login`
- Login page "还没有账户？注册" → goes to `/auth/register`
- Verify page "返回登录" → goes to `/auth/login`
- Reset password page "返回登录" → goes to `/auth/login`
