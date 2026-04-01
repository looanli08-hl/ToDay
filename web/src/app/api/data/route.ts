import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

export const POST = withAuth(async (req: NextRequest, { userId }) => {
  try {
    const body = await req.json();
    const { source, type, value, timestamp, metadata } = body;

    if (!source || !type || value === undefined || !timestamp) {
      return Response.json(
        { error: "Missing required fields: source, type, value, timestamp" },
        { status: 400 }
      );
    }

    const supabase = await createServerSupabaseClient();
    const { data, error } = await supabase.from("data_points").insert({
      user_id: userId,
      source,
      type,
      value: typeof value === "object" ? value : { raw: value },
      timestamp,
      metadata,
    }).select("id").single();

    if (error) {
      return Response.json({ error: "Failed to store data" }, { status: 500 });
    }

    return Response.json({ success: true, id: data.id });
  } catch {
    return Response.json({ error: "Invalid request body" }, { status: 400 });
  }
});

export const GET = withAuth(async (req: NextRequest, { userId }) => {
  const { searchParams } = new URL(req.url);
  const date = searchParams.get("date");
  const source = searchParams.get("source");

  const supabase = await createServerSupabaseClient();

  let query = supabase
    .from("data_points")
    .select("id, source, type, value, timestamp, metadata")
    .eq("user_id", userId)
    .order("timestamp", { ascending: false })
    .limit(200);

  if (source) { query = query.eq("source", source); }
  if (date) { query = query.gte("timestamp", `${date}T00:00:00`).lt("timestamp", `${date}T23:59:59`); }

  const { data } = await query;
  return Response.json({ data: data || [], count: data?.length || 0 });
});
