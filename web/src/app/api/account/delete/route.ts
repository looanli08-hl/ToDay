import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { withAuth } from "@/lib/api/auth";

export const POST = withAuth(async (req: NextRequest, { userId }) => {
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("soft_delete_user_account", {
    p_user_id: userId,
  });

  if (error) {
    return Response.json({ error: "Failed to delete account" }, { status: 500 });
  }

  await supabase.auth.signOut();
  return Response.json({ deleted: true, grace_period_days: 30 });
});
