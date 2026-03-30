import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";

interface SessionPayload {
  domain: string;
  label?: string;
  category: string;
  title?: string;
  startTime: number; // epoch ms
  endTime: number;   // epoch ms
  duration: number;  // seconds
}

export async function POST(req: NextRequest) {
  try {
    // 1. Extract sync token from Authorization header
    const authHeader = req.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return Response.json(
        { error: "Missing Authorization header" },
        { status: 401 }
      );
    }
    const syncToken = authHeader.slice(7).trim();

    // 2. Parse body
    const body = await req.json();
    const sessions: SessionPayload[] = body.sessions;

    if (!Array.isArray(sessions) || sessions.length === 0) {
      return Response.json(
        { error: "sessions must be a non-empty array" },
        { status: 400 }
      );
    }

    // 3. Look up user_id by sync token
    const supabase = await createServerSupabaseClient();
    const { data: userId, error: rpcError } = await supabase.rpc(
      "get_user_id_by_sync_token",
      { token: syncToken }
    );

    if (rpcError || !userId) {
      return Response.json(
        { error: "Invalid sync token" },
        { status: 401 }
      );
    }

    // 4. Insert sessions via RPC (bypasses RLS)
    let inserted = 0;
    let duplicates = 0;

    for (const session of sessions) {
      if (!session.domain || !session.category || !session.startTime || !session.endTime) {
        duplicates++;
        continue;
      }

      const { data } = await supabase.rpc("insert_browsing_session", {
        p_user_id: userId,
        p_domain: session.domain,
        p_label: session.label || null,
        p_category: session.category,
        p_title: session.title || null,
        p_start_time: new Date(session.startTime).toISOString(),
        p_end_time: new Date(session.endTime).toISOString(),
        p_duration_seconds: session.duration,
        p_source: "browser-extension",
      });

      if (data) {
        inserted++;
      } else {
        duplicates++;
      }
    }

    return Response.json({ inserted, duplicates });
  } catch {
    return Response.json({ error: "Invalid request" }, { status: 400 });
  }
}
