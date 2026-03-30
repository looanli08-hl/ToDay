import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/dashboard";

  const url = (process.env.NEXT_PUBLIC_SUPABASE_URL || "").trim();
  const key = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "").trim();

  // Debug: if env vars missing, show error
  if (!url || !key) {
    return NextResponse.redirect(
      `${origin}/dashboard?auth_error=${encodeURIComponent("Missing Supabase env vars: url=" + !!url + " key=" + !!key)}`
    );
  }

  if (code) {
    const cookieStore = await cookies();

    const redirectUrl = `${origin}${next}`;
    const response = NextResponse.redirect(redirectUrl);

    const supabase = createServerClient(url, key, {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            response.cookies.set(name, value, options);
          });
        },
      },
    });

    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return response;
    }

    // Debug: show the actual error
    return NextResponse.redirect(
      `${origin}/dashboard?auth_error=${encodeURIComponent(error.message)}`
    );
  }

  return NextResponse.redirect(
    `${origin}/dashboard?auth_error=${encodeURIComponent("No code parameter in callback")}`
  );
}
