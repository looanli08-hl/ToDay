import { cookies } from "next/headers";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");

  const supabaseUrl = (process.env.NEXT_PUBLIC_SUPABASE_URL || "").trim();
  const supabaseKey = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "").trim();

  if (!code || !supabaseUrl || !supabaseKey) {
    return NextResponse.redirect(`${origin}/dashboard`);
  }

  // Read code_verifier from cookies (set by @supabase/ssr during signInWithOAuth)
  const cookieStore = await cookies();
  const codeVerifierCookie = cookieStore
    .getAll()
    .find((c) => c.name.endsWith("-auth-token-code-verifier"));

  if (!codeVerifierCookie) {
    return NextResponse.redirect(
      `${origin}/auth/login?error=${encodeURIComponent("Code verifier not found")}`
    );
  }

  // Exchange code + code_verifier for session via raw fetch (bypasses Headers bug)
  const tokenRes = await fetch(
    `${supabaseUrl}/auth/v1/token?grant_type=pkce`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: supabaseKey,
      },
      body: JSON.stringify({
        auth_code: code,
        code_verifier: codeVerifierCookie.value,
      }),
    }
  );

  if (!tokenRes.ok) {
    const err = await tokenRes.text();
    return NextResponse.redirect(
      `${origin}/auth/login?error=${encodeURIComponent(err)}`
    );
  }

  const session = await tokenRes.json();

  // Build redirect response and set session cookies manually
  const response = NextResponse.redirect(`${origin}/dashboard`);

  // Derive the cookie name prefix from the Supabase URL
  const projectRef = new URL(supabaseUrl).hostname.split(".")[0];
  const cookiePrefix = `sb-${projectRef}-auth-token`;

  // Store session as chunked cookies (same format @supabase/ssr uses)
  const sessionStr = JSON.stringify(session);
  const chunkSize = 3000;
  const chunks = Math.ceil(sessionStr.length / chunkSize);

  if (chunks === 1) {
    response.cookies.set(cookiePrefix, sessionStr, {
      path: "/",
      maxAge: 60 * 60 * 24 * 365,
      sameSite: "lax",
      secure: true,
      httpOnly: false,
    });
  } else {
    for (let i = 0; i < chunks; i++) {
      response.cookies.set(
        `${cookiePrefix}.${i}`,
        sessionStr.slice(i * chunkSize, (i + 1) * chunkSize),
        {
          path: "/",
          maxAge: 60 * 60 * 24 * 365,
          sameSite: "lax",
          secure: true,
          httpOnly: false,
        }
      );
    }
  }

  // Clean up code verifier cookie
  response.cookies.set(codeVerifierCookie.name, "", {
    path: "/",
    maxAge: 0,
  });

  return response;
}
