"use client";

import { Suspense, useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

function AuthConfirmInner() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const code = searchParams.get("code");
    if (!code) {
      router.push("/dashboard");
      return;
    }

    const supabase = createClient();
    supabase.auth
      .exchangeCodeForSession(code)
      .then(({ error }) => {
        if (error) {
          setError(error.message);
          return;
        }
        router.push("/dashboard");
        router.refresh();
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : "Authentication failed");
      });
  }, [searchParams, router]);

  if (error) {
    return (
      <div className="text-center">
        <p className="text-destructive mb-4">登录失败: {error}</p>
        <a href="/auth/login" className="text-primary hover:underline">
          重新登录
        </a>
      </div>
    );
  }

  return <p className="text-muted-foreground">正在登录...</p>;
}

export default function AuthConfirmPage() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background">
      <Suspense fallback={<p className="text-muted-foreground">正在登录...</p>}>
        <AuthConfirmInner />
      </Suspense>
    </div>
  );
}
