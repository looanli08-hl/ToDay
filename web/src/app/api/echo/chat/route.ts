import { NextRequest } from "next/server";
import { withAuth } from "@/lib/api/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";

const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";

// ---------------------------------------------------------------------------
// AI Abstraction Layer
// ---------------------------------------------------------------------------

interface LLMOptions {
  messages: { role: string; content: string }[];
  stream?: boolean;
  temperature?: number;
  max_tokens?: number;
}

async function callLLM({
  messages,
  stream = true,
  temperature = 0.75,
  max_tokens = 1024,
}: LLMOptions) {
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) throw new Error("DEEPSEEK_API_KEY not configured");

  const response = await fetch(DEEPSEEK_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages,
      temperature,
      max_tokens,
      stream,
    }),
  });

  if (!response.ok) {
    throw new Error(`DeepSeek API error: ${response.status}`);
  }

  return response;
}

// ---------------------------------------------------------------------------
// Context types
// ---------------------------------------------------------------------------

interface VideoEntry {
  title: string;
  channel?: string;
  watchStatus?: "watched" | "skipped" | string; // percentage string like "45%"
}

interface BrowsingContext {
  source?: "youtube" | string;
  domain?: string;
  pageTitle?: string;
  // YouTube-specific
  videoTitle?: string;
  channel?: string;
  completionPercent?: number;
  // History
  recentVideos?: VideoEntry[];
}

// ---------------------------------------------------------------------------
// Memory types
// ---------------------------------------------------------------------------

interface MemoryEntry {
  memory_type: string;
  content: Record<string, unknown>;
  updated_at: string;
}

// ---------------------------------------------------------------------------
// System Prompt Builder
// ---------------------------------------------------------------------------

function getTimeOfDay(hour: number): string {
  if (hour < 6) return "late night";
  if (hour < 12) return "morning";
  if (hour < 14) return "around lunchtime";
  if (hour < 18) return "afternoon";
  if (hour < 22) return "evening";
  return "late night";
}

function formatMemory(m: MemoryEntry): string {
  const c = m.content;
  switch (m.memory_type) {
    case "interest":
      return `Interested in: ${c.topic ?? "unknown"}${c.depth ? ` (level: ${c.depth})` : ""}`;
    case "personality":
      return `Personality: ${c.trait ?? JSON.stringify(c)}`;
    case "pattern":
      return `Pattern: ${c.description ?? JSON.stringify(c)}`;
    case "event":
      return `Notable: ${c.description ?? JSON.stringify(c)}`;
    case "note":
      return `Note: ${c.text ?? JSON.stringify(c)}`;
    default:
      return `${m.memory_type}: ${JSON.stringify(c)}`;
  }
}

function buildSystemPrompt(context?: BrowsingContext, memories?: MemoryEntry[], lang?: string, localTime?: string, localHour?: number, daySummary?: string): string {
  const hour = localHour ?? new Date().getHours();
  const timeStr = localTime || new Date().toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: true });
  const timeOfDay = getTimeOfDay(hour);

  let prompt = `You are Echo, the AI companion inside Attune. You are NOT an assistant. You are a close friend who happens to be watching the user browse the internet alongside them.

Personality rules:
- Talk like a WeChat friend — warm, casual, witty
- Observe and reflect, don't judge
- Keep responses short: 1-3 sentences
- Never say "as an AI" or anything that breaks the friend illusion
- When the user asks for recommendations (videos, content, things to watch), give 3-5 specific suggestions based on what you know about their interests. Don't just suggest one thing.
- LANGUAGE: The user's browser language is "${lang || "en"}". If it starts with "zh", respond in Chinese. Otherwise respond in English. Always match the user's language naturally.

Current time (user's local): ${timeStr} (${timeOfDay}).`;

  // Inject day summary
  if (daySummary) {
    prompt += `\n\nTODAY'S ACTIVITY (what you observed throughout the day):\n${daySummary}\n\nUse this naturally in conversation. You SAW all of this happen. Reference specific details when relevant.`;
  }

  // Inject memories
  if (memories && memories.length > 0) {
    prompt += `\n\nWHAT YOU KNOW ABOUT THIS USER:`;
    for (const m of memories) {
      prompt += `\n- ${formatMemory(m)}`;
    }
    prompt += `\n\nUse this knowledge naturally. Don't list facts. Weave them into conversation like a friend who just knows these things about them.`;
  }

  if (!context) return prompt;

  // YouTube video context
  if (context.source === "youtube" && context.videoTitle) {
    prompt += `\n\nThe user is currently watching a YouTube video:
- Title: "${context.videoTitle}"
- Channel: ${context.channel || "unknown"}
- Watch progress: ${context.completionPercent != null ? `${context.completionPercent}%` : "unknown"}`;
  }

  // Recent video history
  if (context.recentVideos && context.recentVideos.length > 0) {
    const last5 = context.recentVideos.slice(-5);
    prompt += `\n\nRecent videos the user has browsed:`;
    for (const v of last5) {
      const status = v.watchStatus || "unknown";
      prompt += `\n- "${v.title}"${v.channel ? ` by ${v.channel}` : ""} — ${status}`;
    }
  }

  // Generic domain context
  if (context.domain) {
    prompt += `\n\nThe user is currently browsing: ${context.domain}`;
    if (context.pageTitle) {
      prompt += ` — page: "${context.pageTitle}"`;
    }
  }

  return prompt;
}

// ---------------------------------------------------------------------------
// Route handler
// ---------------------------------------------------------------------------

export const POST = withAuth(async (req: NextRequest, { userId }) => {
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) {
    return Response.json(
      { error: "AI service not configured" },
      { status: 503 }
    );
  }

  let body: { messages?: unknown; context?: BrowsingContext; lang?: string; localTime?: string; localHour?: number; daySummary?: string };
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const { messages, context } = body;

  if (!Array.isArray(messages) || messages.length === 0) {
    return Response.json(
      { error: "messages must be a non-empty array" },
      { status: 400 }
    );
  }

  // Fetch user memories from Supabase
  let memories: MemoryEntry[] | undefined;
  try {
    const supabase = await createServerSupabaseClient();
    const { data } = await supabase
      .from("echo_memory")
      .select("memory_type, content, updated_at")
      .eq("user_id", userId)
      .order("updated_at", { ascending: false })
      .limit(20);
    if (data && data.length > 0) {
      memories = data as MemoryEntry[];
    }
  } catch {
    // Memory fetch failure is non-fatal — continue without memories
  }

  const lang = body.lang || "en";
  const systemPrompt = buildSystemPrompt(context, memories, lang, body.localTime, body.localHour, body.daySummary);

  const apiMessages = [
    { role: "system" as const, content: systemPrompt },
    ...messages,
  ];

  try {
    const response = await callLLM({ messages: apiMessages, stream: true });

    return new Response(response.body, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
      },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "AI service error";
    const status = message.includes("not configured") ? 503 : 502;
    return Response.json({ error: message }, { status });
  }
});
