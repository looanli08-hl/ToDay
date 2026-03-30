import { cookies } from "next/headers";
import { NextResponse } from "next/server";

function toBase64Url(str: string): string {
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");

  const supabaseUrl = (process.env.NEXT_PUBLIC_SUPABASE_URL || "").trim();
  const supabaseKey = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "").trim();

  if (!code || !supabaseUrl || !supabaseKey) {
    return NextResponse.redirect(`${origin}/dashboard`);
  }

  try {
    const cookieStore = await cookies();
    const allCookies = cookieStore.getAll();
    const codeVerifierCookie = allCookies.find((c) =>
      c.name.endsWith("-auth-token-code-verifier")
    );

    if (!codeVerifierCookie) {
      return NextResponse.redirect(
        `${origin}/auth/login?error=${encodeURIComponent("Code verifier cookie not found")}`
      );
    }

    // Exchange code via raw fetch (bypasses Supabase JS Headers bug)
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
      const errText = await tokenRes.text();
      return NextResponse.redirect(
        `${origin}/auth/login?error=${encodeURIComponent(errText.slice(0, 200))}`
      );
    }

    const session = await tokenRes.json();
    const response = NextResponse.redirect(`${origin}/dashboard`);

    // Cookie name prefix matching @supabase/ssr format
    const projectRef = new URL(supabaseUrl).hostname.split(".")[0];
    const cookieName = `sb-${projectRef}-auth-token`;

    // Base64url encode the session JSON (same as @supabase/ssr)
    const encoded = toBase64Url(JSON.stringify(session));

    // Chunk into ~3500 char cookies if needed
    const chunkSize = 3500;
    if (encoded.length <= chunkSize) {
      response.cookies.set(cookieName, encoded, {
        path: "/",
        maxAge: 60 * 60 * 24 * 365,
        sameSite: "lax",
        secure: true,
        httpOnly: false,
      });
    } else {
      const chunks = Math.ceil(encoded.length / chunkSize);
      for (let i = 0; i < chunks; i++) {
        response.cookies.set(
          `${cookieName}.${i}`,
          encoded.slice(i * chunkSize, (i + 1) * chunkSize),
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

    // Clean up code verifier
    response.cookies.set(codeVerifierCookie.name, "", {
      path: "/",
      maxAge: 0,
    });

    return response;
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    return NextResponse.redirect(
      `${origin}/auth/login?error=${encodeURIComponent(msg)}`
    );
  }
}
