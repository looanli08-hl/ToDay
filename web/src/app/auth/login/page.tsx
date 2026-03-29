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
  const router = useRouter();
  const supabase = createClient();

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      setError(error.message);
      setLoading(false);
      return;
    }

    router.push("/dashboard");
    router.refresh();
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#F7F3ED]">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex items-center justify-center gap-2.5 mb-8">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-[#e8734a] to-[#f59e6c]">
            <span className="text-sm font-bold text-white">T</span>
          </div>
          <span className="text-xl font-semibold tracking-tight text-[#2D2417]">
            ToDay
          </span>
        </div>

        {/* Card */}
        <div className="rounded-2xl bg-white p-8 shadow-[0_2px_8px_rgba(0,0,0,0.06)]">
          <h1 className="text-xl font-semibold text-[#2D2417] mb-1">
            欢迎回来
          </h1>
          <p className="text-sm text-[#8C7B6B] mb-6">登录你的 ToDay 账户</p>

          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="block text-[13px] font-medium text-[#2D2417] mb-1.5">
                邮箱
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="your@email.com"
                required
                className="w-full rounded-xl border border-[#E5DDD1] bg-[#F7F3ED] px-4 py-2.5 text-sm outline-none focus:ring-2 focus:ring-[#D4864A]/20 focus:border-[#D4864A] transition-all"
              />
            </div>
            <div>
              <label className="block text-[13px] font-medium text-[#2D2417] mb-1.5">
                密码
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                className="w-full rounded-xl border border-[#E5DDD1] bg-[#F7F3ED] px-4 py-2.5 text-sm outline-none focus:ring-2 focus:ring-[#D4864A]/20 focus:border-[#D4864A] transition-all"
              />
            </div>

            {error && (
              <p className="text-sm text-red-500 bg-red-50 rounded-lg px-3 py-2">
                {error}
              </p>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full rounded-xl bg-gradient-to-r from-[#e8734a] to-[#f59e6c] py-2.5 text-sm font-medium text-white shadow-sm hover:shadow transition-all disabled:opacity-50"
            >
              {loading ? "登录中..." : "登录"}
            </button>
          </form>
        </div>

        <p className="text-center text-[13px] text-[#8C7B6B] mt-4">
          还没有账户？{" "}
          <Link
            href="/auth/register"
            className="text-[#D4864A] font-medium hover:underline"
          >
            注册
          </Link>
        </p>
      </div>
    </div>
  );
}
