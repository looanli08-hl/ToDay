import { NextResponse } from "next/server";

// Redirect to client-side handler that exchanges the code
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");

  if (code) {
    // Pass code to client-side page for exchange
    return NextResponse.redirect(
      `${origin}/auth/confirm?code=${encodeURIComponent(code)}`
    );
  }

  return NextResponse.redirect(`${origin}/dashboard`);
}
