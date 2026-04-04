import { NextRequest } from "next/server";
import { withAuth } from "@/lib/api/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

// ---------------------------------------------------------------------------
// GET — Retrieve user's Echo memories
// Optional ?type= query param filter
// ---------------------------------------------------------------------------

export const GET = withAuth(async (req: NextRequest, { userId }) => {
  const supabase = await createServerSupabaseClient();
  const url = new URL(req.url);
  const typeFilter = url.searchParams.get("type");

  let query = supabase
    .from("echo_memory")
    .select("id, memory_type, content, created_at, updated_at")
    .eq("user_id", userId)
    .order("updated_at", { ascending: false })
    .limit(100);

  if (typeFilter) {
    query = query.eq("memory_type", typeFilter);
  }

  const { data, error } = await query;

  if (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }

  return Response.json({ memories: data ?? [] });
});

// ---------------------------------------------------------------------------
// POST — Add new memory
// Body: { memory_type, content }
// ---------------------------------------------------------------------------

export const POST = withAuth(async (req: NextRequest, { userId }) => {
  let body: { memory_type?: string; content?: unknown };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const { memory_type, content } = body;

  const validTypes = ["interest", "personality", "pattern", "event", "note"];
  if (!memory_type || !validTypes.includes(memory_type)) {
    return Response.json(
      { error: `memory_type must be one of: ${validTypes.join(", ")}` },
      { status: 400 }
    );
  }

  if (!content || typeof content !== "object") {
    return Response.json(
      { error: "content must be a non-empty JSON object" },
      { status: 400 }
    );
  }

  const supabase = await createServerSupabaseClient();

  const { data, error } = await supabase.rpc("insert_echo_memory", {
    p_user_id: userId,
    p_memory_type: memory_type,
    p_content: content,
  });

  if (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }

  return Response.json({ id: data }, { status: 201 });
});

// ---------------------------------------------------------------------------
// DELETE — Remove memories
// ?id=<uuid> — delete specific memory (must match user_id)
// No id param — delete ALL user's memories (full reset)
// ---------------------------------------------------------------------------

export const DELETE = withAuth(async (req: NextRequest, { userId }) => {
  const supabase = await createServerSupabaseClient();
  const url = new URL(req.url);
  const memoryId = url.searchParams.get("id");

  if (memoryId) {
    // Delete specific memory
    const { error } = await supabase
      .from("echo_memory")
      .delete()
      .eq("id", memoryId)
      .eq("user_id", userId);

    if (error) {
      return Response.json({ error: error.message }, { status: 500 });
    }
  } else {
    // Delete all user memories (full reset)
    const { error } = await supabase
      .from("echo_memory")
      .delete()
      .eq("user_id", userId);

    if (error) {
      return Response.json({ error: error.message }, { status: 500 });
    }
  }

  return Response.json({ success: true });
});
