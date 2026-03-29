const DEEPSEEK_API_KEY = "sk-94d311f460e54b4cac9c216ed8d5af36";
const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";

const SYSTEM_PROMPT = `你是 Echo，用户生活中温暖而有洞察力的 AI 伙伴。你不是通用 AI 助手——你是一个了解用户生活节奏的朋友。

你的风格：
- 温和、真诚、有同理心
- 简洁不啰嗦，但有深度
- 适当使用 emoji，不过度
- 会主动关心用户的状态
- 回应时结合用户的生活数据（如果有的话）
- 用中文回应

你可以帮助用户：
- 回顾和反思今天的经历
- 分析生活模式和习惯
- 提供情绪支持和建议
- 记录想法和灵感
- 规划日程和目标`;

export async function POST(req: Request) {
  const { messages } = await req.json();

  const apiMessages = [
    { role: "system" as const, content: SYSTEM_PROMPT },
    ...messages,
  ];

  const response = await fetch(DEEPSEEK_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
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
    return Response.json(
      { error: "AI service unavailable" },
      { status: response.status }
    );
  }

  // Forward the SSE stream directly
  return new Response(response.body, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      Connection: "keep-alive",
    },
  });
}
