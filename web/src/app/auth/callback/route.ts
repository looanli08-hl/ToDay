import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/dashboard";

  const url = (process.env.NEXT_PUBLIC_SUPABASE_URL || "").trim();
  const key = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "").trim();

  if (!url || !key) {
    return NextResponse.redirect(`${origin}/dashboard`);
  }

  if (code) {
    const cookieStore = await cookies();

    // Collect cookies during exchange, apply them after
    const pendingCookies: { name: string; value: string; options: Record<string, unknown> }[] = [];

    const supabase = createServerClient(url, key, {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          for (const cookie of cookiesToSet) {
            pendingCookies.push(cookie);
            // Also set on request cookie store for subsequent reads
            try { cookieStore.set(cookie.name, cookie.value, cookie.options); } catch {}
          }
        },
      },
    });

    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (!error) {
      const response = NextResponse.redirect(`${origin}${next}`);
      // Apply collected cookies to the response
      for (const { name, value, options } of pendingCookies) {
        response.cookies.set(name, value, {
          path: (options.path as string) || "/",
          maxAge: options.maxAge as number | undefined,
          domain: options.domain as string | undefined,
          secure: options.secure as boolean | undefined,
          httpOnly: options.httpOnly as boolean | undefined,
          sameSite: options.sameSite as "lax" | "strict" | "none" | undefined,
        });
      }
      return response;
    }

    return NextResponse.redirect(
      `${origin}/dashboard?auth_error=${encodeURIComponent(error.message)}`
    );
  }

  return NextResponse.redirect(`${origin}/dashboard`);
}
