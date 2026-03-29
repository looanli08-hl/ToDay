import { createServerSupabaseClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/dashboard";

  if (code) {
    try {
      const supabase = await createServerSupabaseClient();
      const { error } = await supabase.auth.exchangeCodeForSession(code);
      if (!error) {
        return NextResponse.redirect(`${origin}${next}`);
      }
      console.error("[Auth Callback] Exchange error:", error.message);
    } catch (e) {
      console.error("[Auth Callback] Error:", e);
    }
  }

  // If no code, check for hash-based auth (some OAuth flows use hash fragments)
  // Redirect to dashboard and let client-side handle the session
  return NextResponse.redirect(`${origin}/dashboard`);
}
