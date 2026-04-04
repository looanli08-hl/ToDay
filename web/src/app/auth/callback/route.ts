import { NextResponse } from "next/server";
import { createServerClient } from "@supabase/ssr";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const tokenHash = searchParams.get("token_hash");
  const type = searchParams.get("type");

  // Default redirect
  let redirectTo = `${origin}/auth/login`;

  // Create a response we can mutate cookies on
  const response = NextResponse.redirect(redirectTo);

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return (
            request.headers
              .get("cookie")
              ?.split("; ")
              .map((c) => {
                const [name, ...rest] = c.split("=");
                return { name, value: rest.join("=") };
              }) ?? []
          );
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            response.cookies.set(name, value, options);
          });
        },
      },
    }
  );

  // Handle token_hash flow (email confirmation / password reset without PKCE)
  if (tokenHash && type) {
    const { error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type: type as "signup" | "recovery" | "email",
    });

    if (!error) {
      redirectTo =
        type === "recovery"
          ? `${origin}/auth/update-password`
          : `${origin}/dashboard`;
    } else {
      redirectTo = `${origin}/auth/login?error=${encodeURIComponent(error.message)}`;
    }
  }
  // Handle code flow (PKCE — OAuth or email confirmation with PKCE)
  else if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (!error) {
      redirectTo = `${origin}/dashboard`;
    } else {
      redirectTo = `${origin}/auth/login?error=${encodeURIComponent(error.message)}`;
    }
  }

  // Create final redirect with the correct URL, preserving cookies
  const finalResponse = NextResponse.redirect(redirectTo);
  response.cookies.getAll().forEach((cookie) => {
    finalResponse.cookies.set(cookie.name, cookie.value);
  });

  return finalResponse;
}
