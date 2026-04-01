import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

export const POST = withAuth(async (req: NextRequest, { userId }) => {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("soft_delete_user_data", {
    p_user_id: userId,
  });

  if (error) {
    return Response.json({ error: "Failed to clear data" }, { status: 500 });
  }

  return Response.json({ cleared: true });
});
