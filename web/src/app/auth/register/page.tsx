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
  const supabase = createClient();

  async function handleRegister(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);

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

    router.push("/dashboard");
    router.refresh();
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#F5F1EB]">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex items-center justify-center gap-2.5 mb-8">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-[#C4713E]">
            <span className="text-sm font-semibold text-white">T</span>
          </div>
          <span className="font-display text-xl text-[#2C2418]">
            ToDay
          </span>
        </div>

        {/* Card */}
        <div className="rounded-2xl bg-white p-8 border border-[#E6DFD3]">
          <h1 className="font-display text-xl text-[#2C2418] mb-1">
            创建账户
          </h1>
          <p className="text-sm text-[#8A7D6B] mb-6">开始记录你的生活</p>

          <form onSubmit={handleRegister} className="space-y-4">
            <div>
              <label className="block text-[13px] font-medium text-[#2C2418] mb-1.5">
                名字
              </label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="你的名字"
                required
                className="w-full rounded-xl border border-[#E6DFD3] bg-[#F5F1EB] px-4 py-2.5 text-sm outline-none focus:ring-2 focus:ring-[#C4713E]/20 focus:border-[#C4713E] transition-all"
              />
            </div>
            <div>
              <label className="block text-[13px] font-medium text-[#2C2418] mb-1.5">
                邮箱
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="your@email.com"
                required
                className="w-full rounded-xl border border-[#E6DFD3] bg-[#F5F1EB] px-4 py-2.5 text-sm outline-none focus:ring-2 focus:ring-[#C4713E]/20 focus:border-[#C4713E] transition-all"
              />
            </div>
            <div>
              <label className="block text-[13px] font-medium text-[#2C2418] mb-1.5">
                密码
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="至少 6 位"
                required
                minLength={6}
                className="w-full rounded-xl border border-[#E6DFD3] bg-[#F5F1EB] px-4 py-2.5 text-sm outline-none focus:ring-2 focus:ring-[#C4713E]/20 focus:border-[#C4713E] transition-all"
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
              className="w-full rounded-xl bg-[#C4713E] hover:bg-[#B5633A] py-2.5 text-sm font-medium text-white transition-colors disabled:opacity-50"
            >
              {loading ? "注册中..." : "注册"}
            </button>
          </form>
        </div>

        <p className="text-center text-[13px] text-[#8A7D6B] mt-4">
          已有账户？{" "}
          <Link
            href="/auth/login"
            className="text-[#C4713E] font-medium hover:underline"
          >
            登录
          </Link>
        </p>
      </div>
    </div>
  );
}
