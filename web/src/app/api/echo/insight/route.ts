const DEEPSEEK_API_KEY = "sk-94d311f460e54b4cac9c216ed8d5af36";
const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";

const SYSTEM_PROMPT = `你是 Echo，用户的数字生活伙伴。你了解他们的生活数据，用这些来帮助他们更深地认识自己、更好地生活。

你可以：肯定好的习惯、温柔地提醒、共鸣情绪、感知节奏变化、引发自省、发现跨维度的模式、或只是简单地陪伴。

说什么取决于数据里什么最值得此刻说。像一个真正了解对方的老朋友那样说话。

规则：
- 一句话，不超过50字，中文
- 绝不复述原始数据（如"你今天走了8000步"）
- 绝不给泛泛的健康建议（如"记得多喝水"）
- 根据当前时间调整语气（早上温暖鼓励、深夜关心）
- 如果数据充足，优先做跨维度关联
- 如果数据不多，简单陪伴也可以
- 用「」包裹你的话`;

const NO_DATA_MESSAGE = "连接你的手机或安装浏览器扩展，我就能开始了解你了。第一个发现可能会让你惊讶。";

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { stats, timeline_count, has_data, hour, user_name } = body;

    // No data — return static welcome
    if (!has_data) {
      return Response.json({ message: NO_DATA_MESSAGE });
    }

    // Build dynamic user prompt
    const parts: string[] = [];
    parts.push(`当前时间：${hour < 6 ? "深夜" : hour < 12 ? "上午" : hour < 14 ? "中午" : hour < 18 ? "下午" : hour < 22 ? "晚上" : "深夜"}`);
    if (user_name) parts.push(`用户名：${user_name}`);
    parts.push("");
    parts.push("今日数据：");
    if (stats.steps > 0) parts.push(`- 步数：${stats.steps.toLocaleString()}`);
    if (stats.sleep_hours > 0) parts.push(`- 睡眠：${stats.sleep_hours}小时`);
    if (stats.screen_time_minutes > 0) {
      const h = Math.floor(stats.screen_time_minutes / 60);
      const m = stats.screen_time_minutes % 60;
      parts.push(`- 屏幕时间：${h > 0 ? h + "小时" : ""}${m > 0 ? m + "分钟" : ""}`);
    }
    if (stats.mood_latest) {
      parts.push(`- 心情：${stats.mood_latest.emoji} ${stats.mood_latest.name}（${stats.mood_count}条记录）`);
    }
    if (timeline_count > 0) parts.push(`- 今日事件数：${timeline_count}个`);

    parts.push("");
    parts.push("请基于以上数据，生成一句话。");

    const userPrompt = parts.join("\n");

    const response = await fetch(DEEPSEEK_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${DEEPSEEK_API_KEY}`,
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.8,
        max_tokens: 100,
        stream: false,
      }),
    });

    if (!response.ok) {
      return Response.json({ message: "在这里陪着你。" });
    }

    const result = await response.json();
    const message = result.choices?.[0]?.message?.content?.trim() || "在这里陪着你。";

    return Response.json({ message });
  } catch {
    return Response.json({ message: "在这里陪着你。" });
  }
}
