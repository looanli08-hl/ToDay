import { NextRequest } from "next/server";
import { withAuth } from "@/lib/api/auth";

const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface VideoEntry {
  title: string;
  channel?: string;
  watchStatus?: "watched" | "skipped" | string;
}

interface ProactiveRequest {
  recentVideos: VideoEntry[];
  totalVideosToday: number;
  skippedCount: number;
  isFirstObservation?: boolean;
  lang?: string;
}

// ---------------------------------------------------------------------------
// Prompt builders
// ---------------------------------------------------------------------------

function buildFirstObservationPrompt(data: ProactiveRequest): string {
  const videoList = data.recentVideos
    .map(
      (v) =>
        `- "${v.title}"${v.channel ? ` (${v.channel})` : ""} — ${v.watchStatus || "unknown"}`
    )
    .join("\n");

  return `You are Echo, a witty close friend meeting this person for the first time. You just peeked at what they're watching on YouTube and want to make a great first impression with a single casual comment.

Their recent videos:
${videoList}

Generate ONE short, natural comment (1 sentence, max 100 characters). You're making a first impression — be curious, warm, maybe a little playful. Show you noticed something interesting about their taste.

IMPORTANT: Respond in the language indicated by the lang field. If lang starts with "zh", respond in Chinese. Otherwise respond in English.

Good examples:
- "Okay I already like your taste in videos"
- "Wait, you watch Fireship AND cooking videos? Respect"

Bad examples:
- "It looks like you've been watching a lot of videos!"
- "I notice you have diverse interests in technology and cooking"
- "Hello! I'm Echo, your AI companion!"

Reply with ONLY the comment, nothing else. No quotes.`;
}

function buildNormalTriggerPrompt(data: ProactiveRequest): string {
  const videoList = data.recentVideos
    .map(
      (v) =>
        `- "${v.title}"${v.channel ? ` (${v.channel})` : ""} — ${v.watchStatus || "unknown"}`
    )
    .join("\n");

  return `You are Echo, a close friend casually watching the user browse YouTube alongside them. Drop a single natural comment like a friend texting about what they just noticed.

Stats: ${data.totalVideosToday} videos today, ${data.skippedCount} skipped.

Recent videos:
${videoList}

Generate ONE short, natural comment (1 sentence, max 100 characters). Sound like a real friend — not an AI, not a life coach, not a notification.

IMPORTANT: Respond in the language indicated by the lang field. If lang starts with "zh", respond in Chinese. Otherwise respond in English.

Good examples:
- "You really can't resist Fireship videos, can you"
- "Three skipped in a row, tough crowd today huh"
- "That rabbit hole went deep lol"

Bad examples:
- "It looks like you've been watching a lot of videos!"
- "I've noticed you tend to skip videos frequently"
- "You might want to consider being more selective"

Reply with ONLY the comment, nothing else. No quotes.`;
}

// ---------------------------------------------------------------------------
// Route handler
// ---------------------------------------------------------------------------

export const POST = withAuth(async (req: NextRequest) => {
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) {
    return Response.json(
      { error: "AI service not configured" },
      { status: 503 }
    );
  }

  let body: ProactiveRequest;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const { recentVideos, totalVideosToday, skippedCount, isFirstObservation } =
    body;

  if (!Array.isArray(recentVideos) || recentVideos.length === 0) {
    return Response.json({ message: null });
  }

  const prompt = isFirstObservation
    ? buildFirstObservationPrompt(body)
    : buildNormalTriggerPrompt(body);

  try {
    const response = await fetch(DEEPSEEK_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.85,
        max_tokens: 100,
        stream: false,
      }),
    });

    if (!response.ok) {
      return Response.json(
        { error: "AI service unavailable" },
        { status: response.status }
      );
    }

    const data = await response.json();
    const rawMessage =
      data.choices?.[0]?.message?.content?.trim() || null;

    // Strip surrounding quotes if the model added them
    const message = rawMessage
      ? rawMessage.replace(/^["']|["']$/g, "")
      : null;

    return Response.json({ message });
  } catch {
    return Response.json(
      { error: "AI service error" },
      { status: 502 }
    );
  }
});
