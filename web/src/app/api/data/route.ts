import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";

// In-memory fallback for unauthenticated requests (extension)
const memoryStore: DataPoint[] = [];

interface DataPoint {
  id: string;
  source: string;
  type: string;
  value: Record<string, unknown>;
  timestamp: string;
  metadata?: Record<string, unknown>;
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { source, type, value, timestamp, metadata } = body;

    if (!source || !type || value === undefined || !timestamp) {
      return Response.json(
        { error: "Missing required fields: source, type, value, timestamp" },
        { status: 400 }
      );
    }

    const dataPoint: DataPoint = {
      id: crypto.randomUUID(),
      source,
      type,
      value: typeof value === "object" ? value : { raw: value },
      timestamp,
      metadata,
    };

    // Always store in memory (for extension requests without auth)
    memoryStore.push(dataPoint);

    // Try to store in Supabase too (for persistence)
    try {
      const supabase = await createServerSupabaseClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();

      if (user) {
        await supabase.from("data_points").insert({
          user_id: user.id,
          source: dataPoint.source,
          type: dataPoint.type,
          value: dataPoint.value,
          timestamp: dataPoint.timestamp,
          metadata: dataPoint.metadata,
        });
      }
    } catch {
      // Supabase unavailable — memory store is the fallback
    }

    return Response.json({ success: true, id: dataPoint.id });
  } catch {
    return Response.json({ error: "Invalid request body" }, { status: 400 });
  }
}

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const date = searchParams.get("date");
  const source = searchParams.get("source");

  // Try Supabase first
  let supabaseData: DataPoint[] = [];
  try {
    const supabase = await createServerSupabaseClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (user) {
      let query = supabase
        .from("data_points")
        .select("id, source, type, value, timestamp, metadata")
        .eq("user_id", user.id)
        .order("timestamp", { ascending: false })
        .limit(200);

      if (source) {
        query = query.eq("source", source);
      }

      if (date) {
        query = query
          .gte("timestamp", `${date}T00:00:00`)
          .lt("timestamp", `${date}T23:59:59`);
      }

      const { data } = await query;
      if (data) {
        supabaseData = data.map((d) => ({
          id: d.id,
          source: d.source,
          type: d.type,
          value: d.value as Record<string, unknown>,
          timestamp: d.timestamp,
          metadata: d.metadata as Record<string, unknown> | undefined,
        }));
      }
    }
  } catch {
    // Supabase unavailable
  }

  // Also get from memory store
  let memoryData = [...memoryStore];
  if (date) {
    memoryData = memoryData.filter((d) => d.timestamp.startsWith(date));
  }
  if (source) {
    memoryData = memoryData.filter((d) => d.source === source);
  }

  // Merge and deduplicate (prefer Supabase data)
  const supabaseIds = new Set(supabaseData.map((d) => d.id));
  const merged = [
    ...supabaseData,
    ...memoryData.filter((d) => !supabaseIds.has(d.id)),
  ];

  return Response.json({ data: merged, count: merged.length });
}
