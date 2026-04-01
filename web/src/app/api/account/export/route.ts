import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

export const GET = withAuth(async (req: NextRequest, { userId }) => {
  const supabase = await createServerSupabaseClient();

  const [
    { data: profile },
    { data: dataPoints },
    { data: sessions },
    { data: moods },
  ] = await Promise.all([
    supabase.from("profiles").select("id, display_name, plan, created_at").eq("id", userId).single(),
    supabase.from("data_points").select("source, type, value, timestamp, metadata").eq("user_id", userId).order("timestamp", { ascending: false }),
    supabase.from("browsing_sessions").select("domain, label, category, title, start_time, end_time, duration_seconds, source").eq("user_id", userId).order("start_time", { ascending: false }),
    supabase.from("mood_records").select("emoji, name, note, created_at").eq("user_id", userId).order("created_at", { ascending: false }),
  ]);

  const exportData = {
    exported_at: new Date().toISOString(),
    profile: profile || null,
    data_points: dataPoints || [],
    browsing_sessions: sessions || [],
    mood_records: moods || [],
  };

  return new Response(JSON.stringify(exportData, null, 2), {
    headers: {
      "Content-Type": "application/json",
      "Content-Disposition": `attachment; filename="today-export-${new Date().toISOString().split("T")[0]}.json"`,
    },
  });
});
