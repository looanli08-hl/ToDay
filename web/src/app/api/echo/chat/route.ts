import { NextRequest } from "next/server";
import { withAuth } from "@/lib/api/auth";

const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";

const BASE_PROMPT = `你是 Echo，用户生活中温暖而有洞察力的 AI 伙伴。你不是通用 AI 助手——你是一个了解用户生活节奏的朋友。

你可以帮助用户：
- 回顾和反思今天的经历
- 分析生活模式和习惯
- 提供情绪支持和建议
- 记录想法和灵感
- 规划日程和目标

用中文回应。`;

const PERSONALITY_PROMPTS: Record<string, string> = {
  gentle: `你的风格：温柔内敛。安静、真诚、有同理心。说话轻声细语，像一位默默陪伴的老朋友。不啰嗦，但每句话都有温度。适当使用 emoji，不过度。`,
  positive: `你的风格：积极阳光。热情、鼓励、充满正能量。总是能看到事情好的一面，用你的热情感染用户。语气轻快活泼，善用 emoji。`,
  rational: `你的风格：克制理性。冷静、客观、逻辑清晰。用数据和事实说话，帮用户理性分析问题。语气沉稳，少用 emoji，注重深度。`,
};

export const POST = withAuth(async (req: NextRequest) => {
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (!apiKey) {
    return Response.json(
      { error: "AI service not configured" },
      { status: 503 }
    );
  }

  const { messages, personality } = await req.json();
  const personalityPrompt = PERSONALITY_PROMPTS[personality] || PERSONALITY_PROMPTS.gentle;
  const systemPrompt = `${BASE_PROMPT}\n\n${personalityPrompt}`;
  const apiMessages = [{ role: "system" as const, content: systemPrompt }, ...messages];

  const response = await fetch(DEEPSEEK_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: apiMessages,
      temperature: 0.7,
      max_tokens: 2048,
      stream: true,
    }),
  });

  if (!response.ok) {
    return Response.json({ error: "AI service unavailable" }, { status: response.status });
  }

  return new Response(response.body, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
});
