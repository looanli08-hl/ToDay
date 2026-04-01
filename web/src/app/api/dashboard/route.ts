import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";

async function resolveUserId(req: NextRequest) {
  const authHeader = req.headers.get("authorization");
  if (authHeader?.startsWith("Bearer ")) {
    const token = authHeader.slice(7).trim();
    const supabase = await createServerSupabaseClient();
    const { data: userId } = await supabase.rpc("get_user_id_by_sync_token", { token });
    if (userId) return userId as string;
  }

  const tokenParam = new URL(req.url).searchParams.get("token");
  if (tokenParam) {
    const supabase = await createServerSupabaseClient();
    const { data: userId } = await supabase.rpc("get_user_id_by_sync_token", { token: tokenParam });
    if (userId) return userId as string;
  }

  const supabase = await createServerSupabaseClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user?.id || null;
}

function todayRange() {
  const today = new Date().toISOString().split("T")[0];
  return { start: `${today}T00:00:00`, end: `${today}T23:59:59.999` };
}

function formatMinutes(minutes: number): string {
  if (minutes < 60) return `${minutes}m`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m > 0 ? `${h}h ${m}m` : `${h}h`;
}

export async function GET(req: NextRequest) {
  try {
    const userId = await resolveUserId(req);
    if (!userId) {
      return Response.json({ error: "Not authenticated" }, { status: 401 });
    }

    const supabase = await createServerSupabaseClient();
    const { start, end } = todayRange();

    // Query 1: data_points for today (health data from iOS)
    const { data: dataPoints } = await supabase
      .from("data_points")
      .select("type, value, timestamp")
      .eq("user_id", userId)
      .gte("timestamp", start)
      .lte("timestamp", end)
      .order("timestamp", { ascending: false });

    // Query 2: browsing_sessions for today (from browser extension)
    const { data: sessions } = await supabase
      .from("browsing_sessions")
      .select("domain, category, duration_seconds, start_time")
      .eq("user_id", userId)
      .gte("start_time", start)
      .lte("start_time", end)
      .order("start_time", { ascending: false });

    // Query 3: mood_records for today
    const { data: moods } = await supabase
      .from("mood_records")
      .select("emoji, name, created_at")
      .eq("user_id", userId)
      .gte("created_at", start)
      .lte("created_at", end)
      .order("created_at", { ascending: false });

    // --- Aggregate stats ---
    let steps = 0;
    let sleepHours = 0;
    const healthEvents: { time: string; type: string; label: string }[] = [];

    for (const dp of dataPoints || []) {
      const val = dp.value as Record<string, unknown>;
      const time = new Date(dp.timestamp).toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
        timeZone: "Asia/Shanghai",
      });

      if (dp.type === "steps" && typeof val.duration === "number") {
        steps += Number(val.duration) || 0;
        healthEvents.push({ time, type: "activity", label: `步行 · ${val.displayName || "活动"}` });
      } else if (dp.type === "sleep" && typeof val.duration === "number") {
        sleepHours += (Number(val.duration) || 0) / 3600;
        healthEvents.push({ time, type: "sleep", label: `睡眠 · ${(Number(val.duration) / 3600).toFixed(1)}小时` });
      } else if (dp.type === "workout") {
        healthEvents.push({ time, type: "activity", label: val.displayName as string || "运动" });
      } else if (dp.type !== "mood") {
        healthEvents.push({ time, type: "health", label: val.displayName as string || dp.type });
      }
    }

    // Screen time: sum browsing session durations
    const screenTimeMinutes = sessions
      ? Math.round(sessions.reduce((sum, s) => sum + s.duration_seconds, 0) / 60)
      : 0;

    // Build browsing timeline events (group by hour + category)
    const browsingEvents: { time: string; type: string; label: string }[] = [];
    const categoryByHour = new Map<string, Map<string, number>>();
    for (const s of sessions || []) {
      const hour = new Date(s.start_time).toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
        timeZone: "Asia/Shanghai",
      });
      const hourKey = hour.split(":")[0] + ":00";
      if (!categoryByHour.has(hourKey)) categoryByHour.set(hourKey, new Map());
      const catMap = categoryByHour.get(hourKey)!;
      const cat = s.category || "其他";
      catMap.set(cat, (catMap.get(cat) || 0) + s.duration_seconds);
    }
    for (const [hour, catMap] of categoryByHour) {
      const topCat = Array.from(catMap.entries()).sort((a, b) => b[1] - a[1])[0];
      if (topCat) {
        browsingEvents.push({
          time: hour,
          type: "screen",
          label: `屏幕时间 · ${topCat[0]} ${formatMinutes(Math.round(topCat[1] / 60))}`,
        });
      }
    }

    // Mood
    const moodLatest = moods && moods.length > 0 ? moods[0] : null;
    const moodCount = moods?.length || 0;
    const moodEvents: { time: string; type: string; label: string }[] = (moods || []).map((m) => ({
      time: new Date(m.created_at).toLocaleTimeString("zh-CN", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
        timeZone: "Asia/Shanghai",
      }),
      type: "mood",
      label: `记录心情 · ${m.emoji} ${m.name}`,
    }));

    // Merge and sort timeline
    const timeline = [...healthEvents, ...browsingEvents, ...moodEvents]
      .sort((a, b) => b.time.localeCompare(a.time))
      .slice(0, 20);

    return Response.json({
      stats: {
        steps,
        sleep_hours: Math.round(sleepHours * 10) / 10,
        screen_time_minutes: screenTimeMinutes,
        mood_latest: moodLatest ? { emoji: moodLatest.emoji, name: moodLatest.name } : null,
        mood_count: moodCount,
      },
      timeline,
      has_data: (dataPoints?.length || 0) + (sessions?.length || 0) + (moods?.length || 0) > 0,
    });
  } catch (err) {
    console.error("[dashboard] Error:", err);
    return Response.json({
      stats: { steps: 0, sleep_hours: 0, screen_time_minutes: 0, mood_latest: null, mood_count: 0 },
      timeline: [],
      has_data: false,
    });
  }
}
