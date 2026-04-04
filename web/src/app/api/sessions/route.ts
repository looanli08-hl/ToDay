import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

interface SessionPayload {
  domain: string;
  label?: string;
  category: string;
  title?: string;
  startTime: number;
  endTime: number;
  duration: number;
}

export const POST = withAuth(async (req: NextRequest, { userId }) => {
  try {
    const body = await req.json();
    const sessions: SessionPayload[] = body.sessions;

    if (!Array.isArray(sessions) || sessions.length === 0) {
      return Response.json(
        { error: "sessions must be a non-empty array" },
        { status: 400 }
      );
    }

    const supabase = await createServerSupabaseClient();
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
});
