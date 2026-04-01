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

    return NextResponse.redirect(`${origin}/dashboard`);
  }

  // No code or token_hash — redirect to login
  return NextResponse.redirect(`${origin}/auth/login`);
}
