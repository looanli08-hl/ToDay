import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

// Force Node.js runtime (Edge Runtime has stricter Headers that breaks Supabase JWT)
export const runtime = "nodejs";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/dashboard";

  const url = (process.env.NEXT_PUBLIC_SUPABASE_URL || "").trim();
  const key = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "").trim();

  if (!url || !key || !code) {
    return NextResponse.redirect(`${origin}/dashboard`);
  }

  const cookieStore = await cookies();
  const response = NextResponse.redirect(`${origin}${next}`);

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        for (const { name, value, options } of cookiesToSet) {
          try {
            cookieStore.set(name, value, options);
          } catch {
            // Fallback: set on response
          }
          response.cookies.set(name, value, {
            path: String(options?.path ?? "/"),
            maxAge: options?.maxAge as number | undefined,
            secure: options?.secure as boolean | undefined,
            httpOnly: options?.httpOnly as boolean | undefined,
            sameSite: options?.sameSite as "lax" | "strict" | "none" | undefined,
          });
        }
      },
    },
  });

  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    return NextResponse.redirect(
      `${origin}/dashboard?auth_error=${encodeURIComponent(error.message)}`
    );
  }

  return response;
}
