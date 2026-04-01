import { NextRequest } from "next/server";
import { createServerSupabaseClient } from "@/lib/supabase/server";

type AuthenticatedHandler = (
  req: NextRequest,
  context: { userId: string }
) => Promise<Response>;

export function withAuth(handler: AuthenticatedHandler) {
  return async (req: NextRequest): Promise<Response> => {
    // 1. Try sync token from Authorization: Bearer header
    const authHeader = req.headers.get("authorization");
    if (authHeader?.startsWith("Bearer ")) {
      const token = authHeader.slice(7).trim();
      try {
        const supabase = await createServerSupabaseClient();
        const { data: userId } = await supabase.rpc(
          "get_user_id_by_sync_token",
          { token }
        );
        if (userId) {
          return handler(req, { userId: userId as string });
        }
      } catch {
        // Invalid token format or RPC error — fall through
      }
    }

    // 2. Try Supabase cookie session
    try {
      const supabase = await createServerSupabaseClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (user) {
        return handler(req, { userId: user.id });
      }
    } catch {
      // Session error — fall through
    }

    // 3. No auth — reject
    return Response.json(
      { error: "Authentication required" },
      { status: 401 }
    );
  };
}
