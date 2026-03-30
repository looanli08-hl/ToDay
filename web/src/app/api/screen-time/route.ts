import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";

const DAY_NAMES = ["日", "一", "二", "三", "四", "五", "六"];

function getDateRange(dateStr: string) {
  const start = `${dateStr}T00:00:00`;
  const end = `${dateStr}T23:59:59.999`;
  return { start, end };
}

function emptyResponse() {
  return {
    today: {
      totalMinutes: 0,
      categories: [],
      topSites: [],
      hourly: new Array(24).fill(0),
    },
    yesterday: { totalMinutes: 0 },
    weekly: [],
  };
}

async function resolveUserId(req: NextRequest) {
  // Try sync token from Authorization header first
  const authHeader = req.headers.get("authorization");
  if (authHeader?.startsWith("Bearer ")) {
    const token = authHeader.slice(7).trim();
    const supabase = await createServerSupabaseClient();
    const { data: userId } = await supabase.rpc("get_user_id_by_sync_token", { token });
    if (userId) return userId as string;
  }

  // Try sync token from query param
  const tokenParam = new URL(req.url).searchParams.get("token");
  if (tokenParam) {
    const supabase = await createServerSupabaseClient();
    const { data: userId } = await supabase.rpc("get_user_id_by_sync_token", { token: tokenParam });
    if (userId) return userId as string;
  }

  // Fall back to session auth
  const supabase = await createServerSupabaseClient();
  const { data: { user } } = await supabase.auth.getUser();
  return user?.id || null;
}

export async function GET(req: NextRequest) {
  try {
    const userId = await resolveUserId(req);

    if (!userId) {
      return Response.json({ error: "Not authenticated" }, { status: 401 });
    }

    const supabase = await createServerSupabaseClient();
    const { searchParams } = new URL(req.url);
    const today =
      searchParams.get("date") ||
      new Date().toISOString().split("T")[0];
    const tz = searchParams.get("tz") || "Asia/Shanghai";

    const todayRange = getDateRange(today);

    // Yesterday date
    const yesterdayDate = new Date(today);
    yesterdayDate.setDate(yesterdayDate.getDate() - 1);
    const yesterdayStr = yesterdayDate.toISOString().split("T")[0];
    const yesterdayRange = getDateRange(yesterdayStr);

    // --- Query 1: Today's total ---
    const { data: totalData } = await supabase
      .from("browsing_sessions")
      .select("duration_seconds")
      .eq("user_id", userId)
      .gte("start_time", todayRange.start)
      .lte("start_time", todayRange.end);

    const totalMinutes = totalData
      ? Math.round(
          totalData.reduce((sum, r) => sum + r.duration_seconds, 0) / 60
        )
      : 0;

    // --- Query 2: Categories ---
    const { data: catRows } = await supabase
      .from("browsing_sessions")
      .select("category, duration_seconds")
      .eq("user_id", userId)
      .gte("start_time", todayRange.start)
      .lte("start_time", todayRange.end);

    const catMap = new Map<string, number>();
    for (const row of catRows || []) {
      catMap.set(
        row.category,
        (catMap.get(row.category) || 0) + row.duration_seconds
      );
    }
    const categories = Array.from(catMap.entries())
      .map(([name, seconds]) => ({ name, minutes: Math.round(seconds / 60) }))
      .sort((a, b) => b.minutes - a.minutes);

    // --- Query 3: Top Sites ---
    const { data: siteRows } = await supabase
      .from("browsing_sessions")
      .select("domain, title, duration_seconds")
      .eq("user_id", userId)
      .gte("start_time", todayRange.start)
      .lte("start_time", todayRange.end);

    const siteMap = new Map<string, { title: string; seconds: number }>();
    for (const row of siteRows || []) {
      const existing = siteMap.get(row.domain);
      if (existing) {
        existing.seconds += row.duration_seconds;
        if (row.title) existing.title = row.title;
      } else {
        siteMap.set(row.domain, {
          title: row.title || row.domain,
          seconds: row.duration_seconds,
        });
      }
    }
    const topSites = Array.from(siteMap.entries())
      .map(([domain, { title, seconds }]) => ({
        domain,
        title,
        minutes: Math.round(seconds / 60),
      }))
      .sort((a, b) => b.minutes - a.minutes)
      .slice(0, 10);

    // --- Query 4: Hourly distribution ---
    const { data: hourlyRows } = await supabase
      .from("browsing_sessions")
      .select("start_time, duration_seconds")
      .eq("user_id", userId)
      .gte("start_time", todayRange.start)
      .lte("start_time", todayRange.end);

    const hourly = new Array(24).fill(0);
    for (const row of hourlyRows || []) {
      const hour = new Date(row.start_time).getHours();
      hourly[hour] += row.duration_seconds / 60;
    }
    const hourlyRounded = hourly.map((v: number) => Math.round(v));

    // --- Query 5: Yesterday total ---
    const { data: yesterdayData } = await supabase
      .from("browsing_sessions")
      .select("duration_seconds")
      .eq("user_id", userId)
      .gte("start_time", yesterdayRange.start)
      .lte("start_time", yesterdayRange.end);

    const yesterdayMinutes = yesterdayData
      ? Math.round(
          yesterdayData.reduce((sum, r) => sum + r.duration_seconds, 0) / 60
        )
      : 0;

    // --- Query 6: Weekly (7 days) ---
    const weeklyStart = new Date(today);
    weeklyStart.setDate(weeklyStart.getDate() - 6);
    const weeklyStartStr = weeklyStart.toISOString().split("T")[0];

    const { data: weeklyRows } = await supabase
      .from("browsing_sessions")
      .select("start_time, duration_seconds")
      .eq("user_id", userId)
      .gte("start_time", `${weeklyStartStr}T00:00:00`)
      .lte("start_time", todayRange.end);

    const weeklyMap = new Map<string, number>();
    for (const row of weeklyRows || []) {
      const dateKey = row.start_time.split("T")[0];
      weeklyMap.set(dateKey, (weeklyMap.get(dateKey) || 0) + row.duration_seconds);
    }

    const weekly = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date(today);
      d.setDate(d.getDate() - i);
      const dateStr = d.toISOString().split("T")[0];
      const dayOfWeek = d.getDay();
      weekly.push({
        day: DAY_NAMES[dayOfWeek],
        date: dateStr,
        minutes: Math.round((weeklyMap.get(dateStr) || 0) / 60),
      });
    }

    return Response.json({
      today: {
        totalMinutes,
        categories,
        topSites,
        hourly: hourlyRounded,
      },
      yesterday: { totalMinutes: yesterdayMinutes },
      weekly,
    });
  } catch (err) {
    console.error("[screen-time] Error:", err);
    return Response.json(emptyResponse());
  }
}
