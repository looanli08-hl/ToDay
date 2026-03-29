import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  const url = (process.env.NEXT_PUBLIC_SUPABASE_URL || "").trim();
  const key = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "").trim();

  if (!url || !key) {
    console.error("Supabase env vars missing:", { url: !!url, key: !!key });
    // Return a dummy client that won't crash the page
    return createBrowserClient(
      "https://placeholder.supabase.co",
      "placeholder-key"
    );
  }

  return createBrowserClient(url, key);
}
