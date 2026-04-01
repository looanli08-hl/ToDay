import { createBrowserClient } from "@supabase/ssr";

let client: ReturnType<typeof createBrowserClient> | null = null;

export function createClient() {
  if (client) return client;

  const url = (process.env.NEXT_PUBLIC_SUPABASE_URL || "").trim();
  const key = (process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "").trim();

  if (!url || !key) {
    console.error("Supabase env vars missing:", { url: !!url, key: !!key });
  }

  client = createBrowserClient(
    url || "https://placeholder.supabase.co",
    key || "placeholder-key"
  );

  return client;
}
